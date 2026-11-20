#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="multicloud-devops"
IMAGE="multicloud-task-api:1.0.0"
NAMESPACE="multicloud-devops"

for command in docker kind kubectl; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "Missing required command: $command" >&2
    exit 1
  fi
done

if ! docker info >/dev/null 2>&1; then
  echo "Docker is not running." >&2
  exit 1
fi

if ! kind get clusters | grep -qx "$CLUSTER_NAME"; then
  kind create cluster --name multicloud-devops --config kind/cluster.yaml --wait 120s
fi

docker build --build-arg APP_VERSION=1.0.0 -t "$IMAGE" .
kind load docker-image "$IMAGE" --name "$CLUSTER_NAME"
kubectl apply -k k8s
kubectl rollout status deployment/redis -n "$NAMESPACE" --timeout=120s
kubectl rollout status deployment/task-api -n "$NAMESPACE" --timeout=120s
kubectl get pods,services -n "$NAMESPACE"

echo
echo "Deployment is ready. Run:"
echo "  kubectl port-forward -n $NAMESPACE service/task-api 8000:80"
echo "Then open http://localhost:8000"
