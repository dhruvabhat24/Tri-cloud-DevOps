SHELL := /usr/bin/env bash
IMAGE := multicloud-task-api:1.0.0
CLUSTER := multicloud-devops
NAMESPACE := multicloud-devops

.PHONY: install test lint docker-build compose-up compose-down cluster-create deploy verify destroy tf-check

install:
	python3 -m venv .venv
	.venv/bin/pip install -r requirements-dev.txt

test:
	STORE_BACKEND=memory PYTHONPATH=. .venv/bin/pytest -q

lint:
	.venv/bin/ruff check app tests

docker-build:
	docker build --build-arg APP_VERSION=1.0.0 -t $(IMAGE) .

compose-up:
	docker compose up --build -d

compose-down:
	docker compose down --remove-orphans

cluster-create:
	kind create cluster --name multicloud-devops --config kind/cluster.yaml --wait 120s

deploy: docker-build
	kind load docker-image $(IMAGE) --name $(CLUSTER)
	kubectl apply -k k8s
	kubectl rollout status deployment/redis -n $(NAMESPACE) --timeout=120s
	kubectl rollout status deployment/task-api -n $(NAMESPACE) --timeout=120s

verify:
	./scripts/verify-local.sh

destroy:
	./scripts/destroy-local.sh

tf-check:
	@for dir in terraform/aws terraform/azure terraform/gcp; do \
		echo "Checking $$dir"; \
		terraform -chdir=$$dir fmt -check -recursive; \
		terraform -chdir=$$dir init -backend=false -input=false; \
		terraform -chdir=$$dir validate; \
		terraform -chdir=$$dir test -no-color; \
	done
