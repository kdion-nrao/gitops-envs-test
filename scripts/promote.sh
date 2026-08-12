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
    echo "Promote an image tag from one environment to another"
    echo ""
    echo "Usage: promote.sh APP_NAME SOURCE_ENV TARGET_ENV"
    echo "   APP_NAME       The app to set the tag for."
    echo "                  Must match one of the directories under ${APPS_DIR}/"
    echo "   SOURCE_ENV     The environment name to promote FROM."
    echo "                  Must match one of the directories under ${APPS_DIR}/APP_NAME/envs/"
    echo "   TARGET_ENV     The environment name to promote TO."
    echo "                  Must match one of the directories under ${APPS_DIR}/APP_NAME/envs/"
}

APP_NAME="${1:-}"
if [ -z "$APP_NAME" ]
then
    echo "ERROR: Missing APP_NAME parameter"
    usage
    exit 1
fi

SOURCE_ENV="${2:-}"
if [ -z "$SOURCE_ENV" ]
then
    echo "ERROR: Missing SOURCE_ENV parameter"
    usage
    exit 1
fi

TARGET_ENV="${3:-}"
if [ -z "$TARGET_ENV" ]
then
    echo "ERROR: Missing TARGET_ENV parameter"
    usage
    exit 1
fi

echo "APP_NAME=${APP_NAME}"
echo "SOURCE_ENV=${SOURCE_ENV}"
echo "TARGET_ENV=${TARGET_ENV}"

cd "${SCRIPT_DIR}/.."

if [ ! -d "${APPS_DIR}/${APP_NAME}" ]
then
    echo "App dir not found: ${APPS_DIR}/${APP_NAME}/"
    echo "  Are you using the right APP_NAME?"
    exit 1
fi

if [ ! -d "${APPS_DIR}/${APP_NAME}/envs/${SOURCE_ENV}" ]
then
    echo "Environment dir not found: ${APPS_DIR}/${APP_NAME}/envs/${SOURCE_ENV}/"
    echo "  Are you using the right SOURCE_ENV?"
    exit 1
fi

if [ ! -d "${APPS_DIR}/${APP_NAME}/envs/${TARGET_ENV}" ]
then
    echo "Environment dir not found: ${APPS_DIR}/${APP_NAME}/envs/${TARGET_ENV}/"
    echo "  Are you using the right TARGET_ENV?"
    exit 1
fi

SOURCE_FILE="${APPS_DIR}/${APP_NAME}/envs/${SOURCE_ENV}/values.yaml"
SRC_TAG="$(yq '.image.tag' "$SOURCE_FILE")"
echo "Promoting tag '${SRC_TAG}' from $SOURCE_ENV"

TARGET_FILE="${APPS_DIR}/${APP_NAME}/envs/${TARGET_ENV}/values.yaml"
OLD_TAG="$(yq '.image.tag' "$TARGET_FILE")"
echo "Previous tag in $TARGET_ENV is '${OLD_TAG}'"

echo "Updating $TARGET_FILE"

sed -r "s/^([[:space:]]*tag:)[[:space:]]*${OLD_TAG}/\1 ${SRC_TAG}/" "$TARGET_FILE" > tmp.yaml
mv tmp.yaml "$TARGET_FILE"

NEW_TAG="$(yq '.image.tag' "$TARGET_FILE")"

echo "$TARGET_ENV image tag is now: '$NEW_TAG'"
