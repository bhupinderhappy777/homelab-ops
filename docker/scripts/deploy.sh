#!/usr/bin/env bash
set -euo pipefail

CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-docker}"

if [[ "${CONTAINER_RUNTIME}" == "podman" ]] && command -v podman-compose >/dev/null 2>&1; then
    COMPOSE_CMD=(podman-compose)
else
    COMPOSE_CMD=("${CONTAINER_RUNTIME}" compose)
fi

STACK_NAME=$1

if [ -z "$STACK_NAME" ]; then
    echo "Usage: ./deploy.sh <stack_name>"
    echo "Available stacks:"
    ls -1 stacks/
    exit 1
fi

if [ ! -f "stacks/$STACK_NAME/compose.yml" ]; then
    echo "Error: Stack '$STACK_NAME' not found!"
    exit 1
fi

echo "Deploying $STACK_NAME..."
"${COMPOSE_CMD[@]}" --env-file .env -f "stacks/$STACK_NAME/compose.yml" up -d --remove-orphans
echo "Done!"
