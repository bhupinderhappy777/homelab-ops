#!/usr/bin/env bash
set -euo pipefail

COMPOSE_CMD=(docker compose)

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
