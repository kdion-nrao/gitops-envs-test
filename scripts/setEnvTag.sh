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
    echo "Set the image tag for a given environment config"
    echo ""
    echo "Usage: setEnvTag.sh APP_NAME ENV_NAME IMAGE_TAG"
    echo "   APP_NAME       The app to set the tag for."
    echo "                  Must match one of the directories under ${APPS_DIR}/"
    echo "   ENV_NAME       The environment name to set the tag for."
    echo "                  Must match one of the directories under ${APPS_DIR}/APP_NAME/envs/"
    echo "   IMAGE_TAG      The new value for the image tag"   
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

IMAGE_TAG="${3:-}"
if [ -z "$IMAGE_TAG" ]
then
    echo "ERROR: Missing IMAGE_TAG parameter"
    usage
    exit 1
fi

echo "APP_NAME=${APP_NAME}"
echo "ENV_NAME=${ENV_NAME}"
echo "IMAGE_TAG=${IMAGE_TAG}"

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
echo "Updating $TARGET_FILE"

OLD_TAG="$(yq '.image.tag' "$TARGET_FILE")"
echo "Previous tag is '${OLD_TAG}'"

echo "Updating tag..."

sed -r "s/^([[:space:]]*tag:)[[:space:]]*${OLD_TAG}/\1 ${IMAGE_TAG}/" "$TARGET_FILE" > tmp.yaml
mv tmp.yaml "$TARGET_FILE"

NEW_TAG="$(yq '.image.tag' "$TARGET_FILE")"

echo "$ENV_NAME image tag is now: '$NEW_TAG'"
