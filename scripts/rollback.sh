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

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
APPS_DIR="values/apps"

usage() {
    echo "Roll back the image tag in the given environment to the previous tag"
    echo ""
    echo "Usage: rollback.sh APP_NAME ENV_NAME"
    echo "   APP_NAME       The app to set the tag for."
    echo "                  Must match one of the directories under ${APPS_DIR}/"
    echo "   ENV_NAME       The environment name to roll back."
    echo "                  Must match one of the directories under ${APPS_DIR}/APP_NAME/envs/"
}

APP_NAME="${1:-}"
if [ -z "$APP_NAME" ]
then
    echo "ERROR: Missing APP_NAME parameter"
    usage
    exit 1
fi

ENV_NAME="${2:-}"
if [ -z "$ENV_NAME" ]
then
    echo "ERROR: Missing ENV_NAME parameter"
    usage
    exit 1
fi

echo "APP_NAME=${APP_NAME}"
echo "ENV_NAME=${ENV_NAME}"

cd "${SCRIPT_DIR}/.."

if [ ! -d "${APPS_DIR}/${APP_NAME}" ]
then
    echo "App dir not found: ${APPS_DIR}/${APP_NAME}/"
    echo "  Are you using the right APP_NAME?"
    exit 1
fi

if [ ! -d "${APPS_DIR}/${APP_NAME}/envs/${ENV_NAME}" ]
then
    echo "Environment dir not found: ${APPS_DIR}/${APP_NAME}/envs/${ENV_NAME}/"
    echo "  Are you using the right ENV_NAME?"
    exit 1
fi

TARGET_FILE="${APPS_DIR}/${APP_NAME}/envs/${ENV_NAME}/values.yaml"

CURRENT_TAG="$(yq '.image.tag' "$TARGET_FILE")"
echo "Current tag is '${CURRENT_TAG}'"

PREVIOUS_COMMIT="$(git log --format=%H -2 -- "$TARGET_FILE" | tail -1)"
PREVIOUS_TAG="$(git show "${PREVIOUS_COMMIT}:${TARGET_FILE}" | yq '.image.tag')"
echo "Previous tag is '${PREVIOUS_TAG}'"

echo "Updating tag..."

sed -r "s/^([[:space:]]*tag:)[[:space:]]*${CURRENT_TAG}/\1 ${PREVIOUS_TAG}/" "$TARGET_FILE" > tmp.yaml
mv tmp.yaml "$TARGET_FILE"

NEW_TAG="$(yq '.image.tag' "$TARGET_FILE")"
echo "$ENV_NAME image tag is now: '$NEW_TAG'"
