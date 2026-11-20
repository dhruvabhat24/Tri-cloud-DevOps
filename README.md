# Zero-Cost Multi-Cloud DevOps Project — Intermediate Edition

This repository is a complete learning project that combines:

- Git and GitHub
- Python/FastAPI
- Docker and Docker Compose
- Kubernetes with Kind
- Terraform for AWS, Azure, and GCP
- GitHub Actions CI
- Cost and security guardrails

The application is a task manager. Two API replicas run in Kubernetes and share a Redis data store. The cloud Terraform code models equivalent DevOps services in all three providers:

| Provider | Container registry | Artifact storage |
|---|---|---|
| AWS | Elastic Container Registry (ECR) | Amazon S3 |
| Azure | Azure Container Registry (ACR) | Azure Blob Storage |
| GCP | Artifact Registry | Cloud Storage |

## Important zero-cost boundary

The default workflow creates **no AWS, Azure, or GCP resources**. Cloud code is tested with Terraform mock providers, so no cloud account or credentials are needed.

Do not run a real cloud apply as part of this project. Container registries, object storage, managed Kubernetes, load balancers, public IPs, logging, and data transfer can all produce charges. A budget alert is not a hard spending cap.

## Architecture

```text
Developer
   |
   +--> Git/GitHub
           |
           +--> GitHub Actions
                  |-- Python lint and unit tests
                  |-- Docker image build
                  |-- Disposable Kind integration test
                  `-- Terraform mock tests
                         |-- AWS: ECR + S3 design
                         |-- Azure: ACR + Blob design
                         `-- GCP: Artifact Registry + GCS design

Local machine
   |
   `--> Kind Kubernetes cluster
          |-- task-api replica 1 --+
          |-- task-api replica 2 --+--> Redis
          `-- ClusterIP services
```

## Repository layout

```text
.
├── app/                         FastAPI source and web UI
├── tests/                       Unit tests
├── Dockerfile                   Non-root application image
├── compose.yaml                 App + Redis local stack
├── kind/cluster.yaml            Two-node Kind cluster
├── k8s/                         Kubernetes manifests and Kustomize file
├── terraform/
│   ├── aws/                     ECR + S3 guarded design and mock tests
│   ├── azure/                   ACR + Blob guarded design and mock tests
│   └── gcp/                     Artifact Registry + GCS guarded design and mock tests
├── scripts/                     Bootstrap, verification, and cleanup scripts
├── .github/workflows/ci.yml     CI pipeline
├── Makefile                     Convenience commands
└── README.md
```

## 1. Prerequisites

The easiest Windows setup is Windows 11 + WSL2 Ubuntu + Docker Desktop with WSL integration. Linux and macOS also work.

Install:

- Git
- Python 3.13, or Python 3.12+
- Docker Engine or Docker Desktop
- Docker Compose v2
- kubectl 1.37.x
- Kind 0.33.0
- Terraform 1.17.2, or any Terraform version from 1.7 up to but not including 2.0

Verify:

```bash
git --version
python3 --version
docker version
docker compose version
kubectl version --client
kind version
terraform version
```

Docker must be running before Compose or Kind commands are used.

## 2. Create the project and initialize Git

Enter the repository directory, then run:

```bash
git init
git branch -M main
git add .
git commit -m "Build zero-cost multi-cloud DevOps lab"
```

The `.gitignore` excludes local environments, Terraform state, `.tfvars`, private keys, and common cloud credential files.

## 3. Run unit tests locally

Create an isolated Python environment:

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r requirements-dev.txt
```

On Windows PowerShell without WSL, activation is:

```powershell
.\.venv\Scripts\Activate.ps1
```

Run lint and tests:

```bash
ruff check app tests
STORE_BACKEND=memory PYTHONPATH=. pytest -q
```

Expected result:

```text
3 passed
```

## 4. Run the API directly

The direct run uses the in-memory backend, so Redis is not required:

```bash
STORE_BACKEND=memory \
DEPLOYMENT_TARGET=local-python \
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

Open:

- Web UI: `http://localhost:8000`
- API documentation: `http://localhost:8000/docs`
- Liveness: `http://localhost:8000/health/live`
- Readiness: `http://localhost:8000/health/ready`

Stop with `Ctrl+C`.

## 5. Run with Docker Compose

Build and start the API and Redis:

```bash
docker compose up --build -d
```

Check status and logs:

```bash
docker compose ps
docker compose logs --tail=100 api
docker compose logs --tail=100 redis
```

Verify:

```bash
curl -fsS http://localhost:8000/health/live
curl -fsS http://localhost:8000/health/ready
curl -fsS http://localhost:8000/api/info
```

Create and list a task:

```bash
curl -fsS -X POST http://localhost:8000/api/tasks \
  -H 'Content-Type: application/json' \
  -d '{"title":"Build the multi-cloud project"}'

curl -fsS http://localhost:8000/api/tasks
```

Stop and remove Compose containers:

```bash
docker compose down --remove-orphans
```

Redis persistence is intentionally disabled in this learning project. This avoids local volumes and makes cleanup predictable.

## 6. Build the Docker image manually

```bash
docker build \
  --build-arg APP_VERSION=1.0.0 \
  -t multicloud-task-api:1.0.0 .
```

Inspect it:

```bash
docker image inspect multicloud-task-api:1.0.0
docker history multicloud-task-api:1.0.0
```

The image runs as UID/GID `10001`, has a built-in health check, and does not require root.

A simple memory-backed container test:

```bash
docker run --rm -d \
  --name task-api-test \
  -p 8000:8000 \
  -e STORE_BACKEND=memory \
  -e DEPLOYMENT_TARGET=docker \
  multicloud-task-api:1.0.0

curl -fsS http://localhost:8000/health/live
docker rm -f task-api-test
```

## 7. Create the local Kubernetes cluster

The supplied Kind configuration creates one control-plane node and one worker node.

Automated path:

```bash
./scripts/bootstrap-local.sh
```

Manual path:

```bash
kind create cluster --name multicloud-devops --config kind/cluster.yaml --wait 120s

docker build --build-arg APP_VERSION=1.0.0 \
  -t multicloud-task-api:1.0.0 .

kind load docker-image \
  multicloud-task-api:1.0.0 \
  --name multicloud-devops

kubectl apply -k k8s
```

Wait for both deployments:

```bash
kubectl rollout status deployment/redis \
  -n multicloud-devops --timeout=120s

kubectl rollout status deployment/task-api \
  -n multicloud-devops --timeout=120s
```

Inspect the environment:

```bash
kubectl get nodes -o wide
kubectl get pods,services -n multicloud-devops -o wide
kubectl get resourcequota,limitrange -n multicloud-devops
kubectl describe deployment task-api -n multicloud-devops
```

## 8. Access and verify Kubernetes

Run the automated smoke test:

```bash
./scripts/verify-local.sh
```

It verifies both health endpoints, creates a task, updates it, lists it, and deletes it.

For browser access, start a port-forward in one terminal:

```bash
kubectl port-forward \
  -n multicloud-devops \
  service/task-api 8000:80
```

Then open `http://localhost:8000`.

## 9. Demonstrate Kubernetes capabilities

### Self-healing

List API pods:

```bash
kubectl get pods -n multicloud-devops \
  -l app.kubernetes.io/name=task-api
```

Delete one:

```bash
POD_NAME="$(kubectl get pods -n multicloud-devops \
  -l app.kubernetes.io/name=task-api \
  -o jsonpath='{.items[0].metadata.name}')"

kubectl delete pod "$POD_NAME" -n multicloud-devops
kubectl get pods -n multicloud-devops -w
```

The Deployment controller creates a replacement. Stop watching with `Ctrl+C`.

### Scaling

```bash
kubectl scale deployment/task-api \
  -n multicloud-devops \
  --replicas=3

kubectl rollout status deployment/task-api \
  -n multicloud-devops

kubectl get pods -n multicloud-devops \
  -l app.kubernetes.io/name=task-api
```

Return to the repository baseline:

```bash
kubectl scale deployment/task-api \
  -n multicloud-devops \
  --replicas=2
```

### Rolling update and rollback

Build a new tag:

```bash
docker build --build-arg APP_VERSION=1.0.1 \
  -t multicloud-task-api:1.0.1 .

kind load docker-image \
  multicloud-task-api:1.0.1 \
  --name multicloud-devops
```

Update the Deployment:

```bash
kubectl set image deployment/task-api \
  -n multicloud-devops \
  api=multicloud-task-api:1.0.1

kubectl rollout status deployment/task-api \
  -n multicloud-devops

kubectl rollout history deployment/task-api \
  -n multicloud-devops
```

Rollback demonstration:

```bash
kubectl rollout undo deployment/task-api \
  -n multicloud-devops

kubectl rollout status deployment/task-api \
  -n multicloud-devops
```

Reapplying `kubectl apply -k k8s` restores the declared `1.0.0` image.

## 10. Understand the Kubernetes safeguards

The manifests include:

- Two API replicas
- Shared Redis backing store
- Startup, readiness, and liveness probes
- CPU and memory requests and limits
- Namespace ResourceQuota and LimitRange
- A quota of zero `LoadBalancer` services
- ClusterIP-only services
- Non-root users
- Read-only root filesystems
- Dropped Linux capabilities
- `RuntimeDefault` seccomp profiles
- Disabled service-account token mounting
- PodDisruptionBudget
- NetworkPolicy objects
- Rolling-update strategy

The zero-LoadBalancer quota helps prevent a later deployment from accidentally requesting a cloud load balancer if these manifests are moved to a managed cluster.

## 11. Test Terraform without cloud credentials

Terraform mock providers are supported by Terraform 1.7 and later. They use the provider schemas but generate fake computed values, so these tests do not contact AWS, Azure, or GCP and do not create resources.

Run every stack:

```bash
for cloud in aws azure gcp; do
  terraform -chdir="terraform/${cloud}" fmt -check -recursive
  terraform -chdir="terraform/${cloud}" init -backend=false -input=false
  terraform -chdir="terraform/${cloud}" validate
  terraform -chdir="terraform/${cloud}" test -no-color
done
```

Or use:

```bash
make tf-check
```

Each cloud test verifies three things:

1. Defaults produce zero resource instances.
2. The opt-in configuration is structurally valid under a mock provider.
3. Enabling resources without the exact billing acknowledgement fails.

No cloud environment variables or GitHub secrets are required.

### Cost guard implementation

Every stack contains:

```hcl
variable "enable_cloud_resources" {
  type    = bool
  default = false
}

variable "billing_acknowledgement" {
  type      = string
  default   = ""
}
```

The resource count becomes non-zero only when both conditions are true:

```hcl
local.provision_cloud = (
  var.enable_cloud_resources &&
  var.billing_acknowledgement == "I_UNDERSTAND_THIS_MAY_COST_MONEY"
)
```

Do not place that acknowledgement in the repository. The zero-cost implementation stops at `terraform test`.

## 12. Push to GitHub

Create a new **public** repository without pre-populating it, then connect and push:

```bash
git remote add origin https://github.com/dhruvabhat24/Tri-cloud-DevOps.git
git push -u origin main
```

A public repository is recommended for this lab because standard GitHub-hosted Actions usage in public repositories is free. Check your GitHub billing settings before using a private repository.

Never add AWS keys, Azure credentials, GCP service-account JSON, kubeconfig files, or `.tfvars` containing credentials.

## 13. GitHub Actions pipeline

The workflow runs on pushes and pull requests to `main`.

### Python job

- Uses Python 3.13
- Installs dependencies
- Runs Ruff
- Runs Pytest with the memory backend

### Terraform matrix job

- Runs independently for AWS, Azure, and GCP
- Checks formatting
- Initializes providers without a remote backend
- Validates configuration
- Runs only mocked Terraform tests
- Contains no cloud login
- Contains no infrastructure apply command

### Kubernetes integration job

- Builds the Docker image
- Creates a disposable Kind cluster
- Loads the local image
- Applies Kustomize manifests
- Waits for rollouts
- Executes the API smoke test
- Prints diagnostics if the job fails

View results under the repository's **Actions** tab.

## 14. Strict cloud-charge safeguards

Use all of these controls:

1. Complete the project without creating AWS, Azure, or GCP accounts if possible.
2. Do not configure cloud credentials locally for this repository.
3. Do not add cloud credentials to GitHub Actions secrets.
4. Keep `enable_cloud_resources = false`.
5. Use `terraform test`, not a real cloud deployment.
6. Do not add an infrastructure apply command to CI.
7. Keep Kubernetes services as `ClusterIP`.
8. Retain `services.loadbalancers: "0"` in the namespace quota.
9. Never assume a service is free because it has a free tier.
10. Treat budget alerts as delayed notifications, not spending caps.
11. If you separately experiment with a cloud account, create budget alerts first and manually inspect all regional resources afterward.
12. Avoid managed Kubernetes clusters, NAT gateways, external load balancers, public IPs, managed databases, logging ingestion, container registry storage, object storage, and egress in the zero-cost path.

## 15. Cleanup

Delete the local Kubernetes cluster:

```bash
./scripts/destroy-local.sh
```

Or:

```bash
kind delete cluster --name multicloud-devops
```

Clean Compose resources and the local image:

```bash
docker compose down --remove-orphans
docker image rm multicloud-task-api:1.0.0 || true
```

Remove Python and Terraform caches:

```bash
rm -rf .venv .pytest_cache .ruff_cache
find terraform -type d -name .terraform -prune -exec rm -rf {} +
```

Terraform state is not expected because the zero-cost workflow never performs a real apply.

## 16. Troubleshooting

### Docker daemon unavailable

Start Docker Desktop or Docker Engine, then verify:

```bash
docker info
```

### Kind image pull or startup issue

```bash
kind delete cluster --name multicloud-devops
kind create cluster --name multicloud-devops --config kind/cluster.yaml --wait 120s
```

### API pods show `ImagePullBackOff`

The image was not loaded into Kind, or the tag differs:

```bash
docker images | grep multicloud-task-api
kind load docker-image multicloud-task-api:1.0.0 --name multicloud-devops
kubectl rollout restart deployment/task-api -n multicloud-devops
```

### API pods are not ready

```bash
kubectl get pods -n multicloud-devops
kubectl describe pods -n multicloud-devops
kubectl logs deployment/task-api -n multicloud-devops --all-containers=true
kubectl logs deployment/redis -n multicloud-devops --all-containers=true
```

### Terraform asks for cloud credentials

Stop. The zero-cost path should use the test files containing `mock_provider`. Confirm the command is:

```bash
terraform -chdir=terraform/aws test
```

and not a normal cloud deployment command.

### Port 8000 is already in use

Use another local port:

```bash
kubectl port-forward -n multicloud-devops service/task-api 8080:80
```

Then open `http://localhost:8080`.

## 17. Completion checklist

- [ ] Python tests pass
- [ ] Ruff passes
- [ ] Compose app and Redis become healthy
- [ ] Docker image runs as non-root
- [ ] Kind cluster has two nodes
- [ ] Two API pods and one Redis pod are ready
- [ ] Smoke test passes
- [ ] Self-healing demonstration works
- [ ] Scaling and rolling update are demonstrated
- [ ] AWS mock tests pass
- [ ] Azure mock tests pass
- [ ] GCP mock tests pass
- [ ] GitHub Actions is green
- [ ] No cloud credentials are stored
- [ ] No real cloud resources are created

## Resume description

> Built a zero-cost multi-cloud DevOps lab using Git, Docker, Kubernetes, Terraform, and GitHub Actions. Containerized a FastAPI service, deployed replicated workloads with Redis to a local Kind cluster, implemented health probes and Kubernetes security controls, and modeled equivalent AWS, Azure, and GCP registry/storage infrastructure. Added credential-free Terraform provider mocks and end-to-end CI integration tests while preventing accidental cloud provisioning through explicit cost guardrails.
