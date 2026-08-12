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
    echo "Get the previous image tags for the given app + env"
    echo ""
    echo "Usage: prevTags.sh APP_NAME ENV_NAME"
    echo "   APP_NAME       The app name."
    echo "                  Must match one of the directories under ${APPS_DIR}/"
    echo "   ENV_NAME       The environment name get previous tags for."
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

declare -A TAGS

CURRENT_TAG="$(yq '.image.tag' "$TARGET_FILE")"
TAGS["$CURRENT_TAG"]=0
echo "Current tag is '${CURRENT_TAG}'"

readarray -t PREVIOUS_COMMITS <<<"$(git log --format=%H --follow -- "$TARGET_FILE")"
# echo "${PREVIOUS_COMMITS[@]}"
for COMMIT in "${PREVIOUS_COMMITS[@]}"
do
    # echo "$COMMIT"
    PREVIOUS_TAG="$(git show "${COMMIT}:${TARGET_FILE}" | yq '.image.tag // ""')"
    if [ -n "$PREVIOUS_TAG" ]
    then
        TAGS["$PREVIOUS_TAG"]="$COMMIT"
        echo "${COMMIT}: '${PREVIOUS_TAG}'"
    fi

    if git diff-tree --find-renames -r --name-status --diff-filter=R --no-commit-id "$COMMIT" | grep "$TARGET_FILE" &> /dev/null
    then
        RENAME="$(git diff-tree --find-renames -r --name-status --diff-filter=R --no-commit-id "$COMMIT" | grep "$TARGET_FILE" | awk '{print $2}')"
        if [ -n "$RENAME" ]
        then
            echo "Renamed: ${RENAME} -> ${TARGET_FILE}"
            TARGET_FILE="$RENAME"
        fi
    fi
done
echo "Tags: ${!TAGS[@]}"
