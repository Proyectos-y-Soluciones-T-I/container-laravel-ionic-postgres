# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

Infrastructure-only Docker environment for the **Ayudando** project (Laravel 8 + Ionic/Angular 17 + PostgreSQL). No application source code lives here. The project source (`ayudando/`) is cloned locally and **never modified from this repo**.

## Critical Rule

**NEVER touch files inside `ayudando/`.** All Docker-related files go in the repo root or under `docker/`.

## Services

| Container | Image | Port | Role |
|---|---|---|---|
| `ayudando_postgres` | postgres:14.22-alpine | 5432 | Database |
| `ayudando_pgadmin` | dpage/pgadmin4:7.3 | 5050 | DB admin UI |
| `ayudando_backend` | (build) PHP 8.0-fpm | — | Laravel via FPM |
| `ayudando_nginx` | nginx:1.25-alpine | 8080 | Reverse proxy → FPM on `:9000` |
| `ayudando_frontend` | (build) Node 18.16.1 | 4200 | Ionic/Angular dev server |

All services share `ayudando_net` bridge network.

## Common Commands

```bash
make up              # docker compose up -d
make down            # docker compose down
make build           # docker compose build --no-cache
make logs            # docker compose logs -f
make ps              # docker compose ps

make shell-backend   # sh into PHP container
make shell-frontend  # sh into Node container
make shell-db        # psql into postgres

make db-import       # pg_restore from ayudando/ayudando.tar
make migrate         # php artisan migrate
make fresh           # php artisan migrate:fresh --seed
make cache-clear     # config:clear + cache:clear + route:clear
make artisan cmd="<command>"   # any artisan command
```

First-time setup:
```bash
cp .env.example .env   # fill in credentials
docker compose up -d --build
make db-import
```

Reset DB entirely:
```bash
docker compose down -v   # WARNING: destroys all volumes
make up && make db-import
```

## Architecture Decisions

**DB dump format**: `.tar` (not `.sql`). Import uses `pg_restore --no-owner --no-acl`, not `psql`. File: `ayudando/ayudando.tar`.

**node_modules isolation**: Frontend `node_modules` live in a named Docker volume (`frontend_node_modules`), NOT bind-mounted. This avoids Windows bind-mount performance issues.

**File upload limits**: All tuned to 500 MB across nginx (`client_max_body_size`) and PHP (`upload_max_filesize`, `post_max_size`, `memory_limit`). Timeout 600s everywhere. See `docker/nginx/nginx.conf` and `docker/php/php.ini`.

**Frontend polling**: `ng serve` runs with `--poll 1000` for Windows file-change detection.

**Entrypoints auto-setup**:
- Backend (`docker/php/entrypoint.sh`): runs `composer install`, `artisan storage:link`, `chmod 775` on first start.
- Frontend (`docker/frontend/entrypoint.sh`): runs `npm install --legacy-peer-deps` then `ng serve`.

## Required `.env` Variables

These MUST be set or the containers fail to start:

```
POSTGRES_PASSWORD
PGADMIN_PASSWORD
APP_KEY          # generate: docker exec ayudando_backend php artisan key:generate
JWT_SECRET
MAIL_HOST
MAIL_USERNAME
MAIL_PASSWORD
```

## Troubleshooting

**Backend can't reach DB**: check `docker compose ps` — postgres must show `(healthy)`. Root cause is usually missing `POSTGRES_PASSWORD` in `.env`.

**Composer fails in container**: `make shell-backend` → `composer install --ignore-platform-reqs -vvv`. If `tymon/jwt-auth` conflicts with PHP 8.0, downgrade to `php:7.4-fpm-alpine` in `docker/php/Dockerfile`.

**pgAdmin can't connect**: host must be `postgres` (service name), port `5432` (internal), not `localhost`.

**Port conflict**: override in `.env` — `NGINX_PORT`, `FRONTEND_PORT`, `PGADMIN_PORT`, `POSTGRES_PORT`.

**Frontend changes not detected**: `docker compose restart frontend`.
