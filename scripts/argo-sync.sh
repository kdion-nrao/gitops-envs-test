#!/usr/bin/env bash
set -eEuo pipefail

exit_trap() {
    echo "Exiting with status code $?"
}

error_handler() {
    local exit_code=$?
    local line_number=$1
    echo "[ERROR] Command failed with exit code $exit_code at line $line_number" >&2
}

trap 'error_handler $LINENO' ERR
trap exit_trap EXIT SIGINT SIGTERM

APP_NAME="dummy-app-dev"

# argocd app sync ${APP_NAME}  --grpc-web
STATUS="$(argocd app get ${APP_NAME} -o json --grpc-web | jq -r '.status.sync.status')"

echo "$STATUS"
