#!/usr/bin/env bash
set -eEuo pipefail

## Generate a list of age recipient keys based on a list of GitHub usernames read from .sops.users

exit() {
    echo "=== Exiting"
}

error_handler() {
    local exit_code=$?
    local line_number=$1
    echo "[ERROR] Command failed with exit code $exit_code at line $line_number" >&2
}

trap 'error_handler $LINENO' ERR
trap exit EXIT SIGINT SIGTERM

## Check for required commands
required_commands=(yq sops)
missing_commands=()

for cmd in "${required_commands[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        missing_commands+=("$cmd")
    fi
done

if ((${#missing_commands[@]} > 0)); then
    printf 'Error: missing required commands: %s\n' "${missing_commands[*]}" >&2
    exit 1
fi

ALL_KEYS=()

get_keys_for_user() {
    local username="$1"

    echo "== Getting keys for: $username"

    local keys_url="https://github.com/${username}.keys"

    if ! keys_list="$(curl -s --show-error --fail "$keys_url")"
    then
        echo "[WARN] Failed to get user's keys - skipping"
        return
    fi

    local count=0
    mapfile -t ssh_keys <<< "$keys_list"
    for key in "${ssh_keys[@]}"
    do
        ## Only ssh-ed25519 and ssh-rsa keys
        if [[ "$key" =~ ^ssh-(ed25519|rsa)[[:space:]]  ]]
        then
            ALL_KEYS+=("$key")
            ((++count))
        fi
    done
    echo "Found $count keys"
}

readarray -t usernames < <(yq '.age.github-users[]' .sopsgen.cfg.yaml)
for username in "${usernames[@]}"
do
    get_keys_for_user "$username"
done

readarray -t static_keys < <(yq '.age.keys[]' .sopsgen.cfg.yaml)
echo "== Adding ${#static_keys[@]} static keys"
for key in "${static_keys[@]}"
do
    ALL_KEYS+=("$key")
done

## Write keys to .sops.yaml
echo "=== Writing ${#ALL_KEYS[@]} keys to sops config"
## clear existing
yq -i '.creation_rules[].age = []' .sops.yaml
## add keys
for key in "${ALL_KEYS[@]}"
do
    key="$key" yq -i '.creation_rules[].age += strenv(key)' .sops.yaml
done

## Re-encrypt secret files
echo "=== Updating keys "
shopt -s globstar nullglob
for file in ./**/*secret*.enc.yaml
do
    sops updatekeys -y "$file"
done