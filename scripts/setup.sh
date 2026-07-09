#!/usr/bin/env bash
# setup.sh — Bootstrap env files and start a project.
#
# Usage:
#   ./scripts/setup.sh ayudando
#   ./scripts/setup.sh emergencias
#   ./scripts/setup.sh fiscalizacion
#
# What it does:
#   1. Validates the project name.
#   2. Creates .env and envs/<project>.env from .example if they don't exist.
#   3. Exits with instructions if either file was just created (needs filling in).
#   4. Runs docker compose up -d.

set -euo pipefail

VALID_PROJECTS="ayudando emergencias fiscalizacion"

red()   { printf '\033[0;31m%s\033[0m\n' "$*"; }
green() { printf '\033[0;32m%s\033[0m\n' "$*"; }
bold()  { printf '\033[1m%s\033[0m\n' "$*"; }

PROJECT="${1:-}"

if [ -z "$PROJECT" ]; then
    red "Error: missing project name."
    echo "Usage: ./scripts/setup.sh <project>"
    echo "       Valid projects: ${VALID_PROJECTS}"
    exit 1
fi

valid=0
for v in $VALID_PROJECTS; do
    if [ "$PROJECT" = "$v" ]; then valid=1; break; fi
done

if [ "$valid" -ne 1 ]; then
    red "Error: '${PROJECT}' is not a valid project."
    echo "Valid options: ${VALID_PROJECTS}"
    exit 1
fi

# ─── Bootstrap env files ─────────────────────────────────────────────────────
needs_fill=0

if [ ! -f ".env" ]; then
    cp .env.example .env
    bold "Created .env from .env.example"
    needs_fill=1
fi

mkdir -p envs
if [ ! -f "envs/${PROJECT}.env" ]; then
    cp "envs/${PROJECT}.env.example" "envs/${PROJECT}.env"
    bold "Created envs/${PROJECT}.env from example"
    needs_fill=1
fi

if [ "$needs_fill" -eq 1 ]; then
    echo ""
    red "Fill in the required values before starting:"
    echo "  .env                   — POSTGRES_PASSWORD, PGADMIN_PASSWORD"
    echo "  envs/${PROJECT}.env    — APP_KEY, JWT_SECRET, MAIL_* credentials"
    echo ""
    echo "Tip: use the dashboard generator at http://localhost:8090"
    exit 1
fi

# ─── Docker Compose up ───────────────────────────────────────────────────────
bold "Starting ${PROJECT}..."
docker compose \
    -f "docker-compose.${PROJECT}.yml" \
    --project-name "${PROJECT}" \
    up -d

echo ""
green "Done. Follow logs with:"
echo "  docker compose -f docker-compose.${PROJECT}.yml --project-name ${PROJECT} logs -f"
