#!/usr/bin/env bash
# setup.sh — Interactive project setup with optional @ngx-formly installation.
#
# Usage:
#   ./scripts/setup.sh ayudando
#   ./scripts/setup.sh emergencias
#   ./scripts/setup.sh fiscalizacion
#
# What it does:
#   1. Validates the project name.
#   2. Asks whether to install @ngx-formly (installed via npm on first container start).
#   3. Runs docker compose up -d with INSTALL_FORMLY set accordingly.

set -euo pipefail

# ─── Config ──────────────────────────────────────────────────────────────────
VALID_PROJECTS="ayudando emergencias fiscalizacion"

# ─── Helpers ─────────────────────────────────────────────────────────────────
red()    { printf '\033[0;31m%s\033[0m\n' "$*"; }
green()  { printf '\033[0;32m%s\033[0m\n' "$*"; }
bold()   { printf '\033[1m%s\033[0m\n' "$*"; }

# ─── Argument validation ─────────────────────────────────────────────────────
PROJECT="${1:-}"

if [ -z "$PROJECT" ]; then
    red "Error: missing project name."
    echo "Usage: ./scripts/setup.sh <project>"
    echo "       Valid projects: ${VALID_PROJECTS}"
    exit 1
fi

valid=0
for v in $VALID_PROJECTS; do
    if [ "$PROJECT" = "$v" ]; then
        valid=1
        break
    fi
done

if [ "$valid" -ne 1 ]; then
    red "Error: '${PROJECT}' is not a valid project."
    echo "Valid options: ${VALID_PROJECTS}"
    exit 1
fi

# ─── @ngx-formly prompt ──────────────────────────────────────────────────────
export INSTALL_FORMLY=no

echo ""
bold "[@ngx-formly]"
printf "  Install @ngx-formly into the ${PROJECT} frontend? (installs via npm on first start) [y/N] "
read -r answer </dev/tty
case "$answer" in
    y|Y|yes|YES)
        export INSTALL_FORMLY=yes
        green "  @ngx-formly will be installed via npm on first container start."
        ;;
    *)
        echo "  Skipping @ngx-formly installation."
        ;;
esac
echo ""

# ─── Docker Compose up ───────────────────────────────────────────────────────
bold "Starting ${PROJECT}..."
docker compose \
    -f "docker-compose.${PROJECT}.yml" \
    --project-name "${PROJECT}" \
    up -d

echo ""
green "Done. To follow frontend logs:"
echo "  docker compose -f docker-compose.${PROJECT}.yml --project-name ${PROJECT} logs -f frontend"
