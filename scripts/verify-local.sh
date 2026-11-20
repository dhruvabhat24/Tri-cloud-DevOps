#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="multicloud-devops"
LOCAL_PORT="18000"
LOG_FILE="${TMPDIR:-/tmp}/multicloud-port-forward.log"

kubectl rollout status deployment/redis -n "$NAMESPACE" --timeout=120s
kubectl rollout status deployment/task-api -n "$NAMESPACE" --timeout=120s

kubectl port-forward -n "$NAMESPACE" service/task-api "$LOCAL_PORT":80 >"$LOG_FILE" 2>&1 &
PORT_FORWARD_PID=$!
cleanup() {
  kill "$PORT_FORWARD_PID" >/dev/null 2>&1 || true
}
trap cleanup EXIT

for _ in $(seq 1 30); do
  if curl -fsS "http://127.0.0.1:${LOCAL_PORT}/health/ready" >/dev/null; then
    break
  fi
  sleep 1
done

curl -fsS "http://127.0.0.1:${LOCAL_PORT}/health/live"
echo
curl -fsS "http://127.0.0.1:${LOCAL_PORT}/health/ready"
echo

created="$({ curl -fsS -X POST "http://127.0.0.1:${LOCAL_PORT}/api/tasks" \
  -H 'Content-Type: application/json' \
  -d '{"title":"Kubernetes smoke test"}'; } )"
echo "$created"

task_id="$(printf '%s' "$created" | python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])')"
curl -fsS -X PATCH "http://127.0.0.1:${LOCAL_PORT}/api/tasks/${task_id}" \
  -H 'Content-Type: application/json' \
  -d '{"completed":true}'
echo
curl -fsS "http://127.0.0.1:${LOCAL_PORT}/api/tasks"
echo
curl -fsS -X DELETE "http://127.0.0.1:${LOCAL_PORT}/api/tasks/${task_id}" >/dev/null

echo "Local Kubernetes smoke test passed."
