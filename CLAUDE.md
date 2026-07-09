# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Command Style — CRITICAL

**Always use native Docker commands. Never suggest `make` as the primary command.**

When providing commands, always show the full `docker` / `docker compose` form first.
`make` equivalents may appear as a secondary reference, never as the main instruction.

```bash
# ✅ Correct
docker compose -f docker-compose.ayudando.yml --project-name ayudando up -d

# ✅ Also acceptable as a note
# Shortcut: make up PROJECT=ayudando

# ❌ Never do this as the primary command
make up PROJECT=ayudando
```

---

## What This Repo Is

Infrastructure-only Docker environment for multiple projects (Ayudando, Emergencias, Fiscalización) —
Laravel 8 + Ionic/Angular 17 + PostgreSQL 14. No application source code lives here.
Project sources live in `src/<project>/` and are **never modified from this repo**.

## Critical Rule

**NEVER touch files inside `src/`.** All Docker-related files go in the repo root or under `docker/`.

---

## Architecture

Two-layer stack:

**Shared** (always running):
```bash
docker compose -f docker-compose.shared.yml up -d
```

**Per project** (one at a time):
```bash
docker compose -f docker-compose.<project>.yml --project-name <project> up -d
```

## Services

### Shared (docker-compose.shared.yml)

| Container | Image | Port | Role |
|---|---|---|---|
| `shared_postgres` | postgres:14.22-alpine | 5432 | Shared database |
| `shared_pgadmin` | dpage/pgadmin4:7.3 | 5050 | DB admin UI |
| `shared_dashboard` | nginx:1.25-alpine | 8090 | Dev dashboard |

### Per project

| Container | Image | Port | Role |
|---|---|---|---|
| `<project>_backend` | (build) PHP 8.1-fpm | — | Laravel via FPM |
| `<project>_nginx` | nginx:1.25-alpine | 8080/81/82 | Reverse proxy → FPM :9000 |
| `<project>_frontend` | (build) Node 18.16.1 | 4200/01/02 | Ionic/Angular dev server |
| `<project>_redis` | redis:7-alpine | — | Sessions + cache |

## Common Commands

### Shared infrastructure

```bash
docker compose -f docker-compose.shared.yml up -d
docker compose -f docker-compose.shared.yml down
docker compose -f docker-compose.shared.yml ps
docker compose -f docker-compose.shared.yml logs -f
```

### Project lifecycle (replace `ayudando` with `emergencias` or `fiscalizacion`)

```bash
# Up / down / build
docker compose -f docker-compose.ayudando.yml --project-name ayudando up -d
docker compose -f docker-compose.ayudando.yml --project-name ayudando down
docker compose -f docker-compose.ayudando.yml --project-name ayudando build --no-cache
docker compose -f docker-compose.ayudando.yml --project-name ayudando logs -f
docker compose -f docker-compose.ayudando.yml --project-name ayudando ps
docker compose -f docker-compose.ayudando.yml --project-name ayudando restart

# Shell access
docker exec -it ayudando_backend sh
docker exec -it ayudando_frontend sh
docker exec -it shared_postgres psql -U postgres -d ayudando

# Artisan
docker exec ayudando_backend php artisan key:generate
docker exec ayudando_backend php artisan migrate
docker exec ayudando_backend php artisan migrate:fresh --seed
docker exec ayudando_backend php artisan config:clear
docker exec ayudando_backend php artisan cache:clear
docker exec ayudando_backend php artisan route:clear

# DB import (pg_restore — NOT psql)
docker exec -i shared_postgres pg_restore -U postgres -d ayudando --no-owner --no-acl < src/ayudando/ayudando.tar
```

### First-time setup

```bash
cp .env.example .env
# fill in credentials in .env
docker compose -f docker-compose.shared.yml up -d
# wait for shared_postgres to be (healthy)
docker compose -f docker-compose.ayudando.yml --project-name ayudando up -d
docker exec ayudando_backend php artisan key:generate
docker exec -i shared_postgres pg_restore -U postgres -d ayudando --no-owner --no-acl < src/ayudando/ayudando.tar
```

### Reset DB entirely

```bash
docker compose -f docker-compose.shared.yml down -v   # WARNING: destroys all volumes
docker compose -f docker-compose.shared.yml up -d
docker exec -i shared_postgres pg_restore -U postgres -d ayudando --no-owner --no-acl < src/ayudando/ayudando.tar
```

---

## Upgrading a Project's Stack Version

Use this guide when a project needs to move to a new Node, Angular, Ionic, or PHP version.
The container repo only changes Docker infrastructure — the app repo migration is a separate concern.

### 1. Create a branch

```bash
git checkout main
git pull origin main
git checkout -b feat/docker-node22-ng20-<project>
```

### 2. Update the Docker images (container repo)

**Frontend — Node or Angular CLI version** (`docker/frontend/Dockerfile`):
> `docker/frontend/Dockerfile` is **shared** — changing it affects all projects on next rebuild.

```dockerfile
# Bump Node
FROM node:22-alpine

# Bump Angular CLI global (matches the app's major Angular version)
RUN npm install -g @ionic/cli@7.2.1 @angular/cli@20.3.31 --legacy-peer-deps
```

**Backend — PHP version** (`docker/php/Dockerfile`):

```dockerfile
# Use latest patch of the desired minor (avoid pinning Alpine minor — 3.17 is EOL)
FROM php:8.1-fpm-alpine
```

### 3. Update the project compose file

Edit `docker-compose.<project>.yml`:

```yaml
# Frontend service — increase NODE_OPTIONS if Angular version is heavier
environment:
  NODE_OPTIONS: --max_old_space_size=4096   # was 3072 for Angular 17

# Update the comment on the service to reflect the new stack
# ─── Ionic 8 / Angular 20 (dev server) ──
```

### 4. Rebuild and bring up

```bash
# Bring down first (not needed if stack was never up)
docker compose -f docker-compose.<project>.yml --project-name <project> down

# Rebuild images with no cache
docker compose -f docker-compose.<project>.yml --project-name <project> build --no-cache

# Start
docker compose -f docker-compose.<project>.yml --project-name <project> up -d
```

### 5. Verify

```bash
# Check all containers are up
docker compose -f docker-compose.<project>.yml --project-name <project> ps

# Backend: PHP-FPM must show "ready to handle connections"
docker logs <project>_backend --tail 20

# Frontend: ng serve must be compiling (no SIGKILL = enough memory)
docker logs <project>_frontend --tail 30

# Version JSON written by entrypoint (auto-detected by dashboard)
docker exec <project>_backend sh -c "cat /versions/<project>-backend.json"
docker exec <project>_frontend sh -c "cat /versions/<project>-frontend.json"
```

### 6. Entrypoint changes — no rebuild needed

`docker/php/entrypoint.sh` and `docker/frontend/entrypoint.sh` are **bind-mounted** at runtime.
Changes take effect on `restart` without rebuilding:

```bash
# Edit entrypoint, then:
docker compose -f docker-compose.<project>.yml --project-name <project> restart backend
docker compose -f docker-compose.<project>.yml --project-name <project> restart frontend
```

### 7. Dashboard version pills

The dashboard auto-detects versions from the shared `stack_versions` volume.
No manual HTML update is needed — version pills update on next page load after the containers start.

### Stack version reference

| Project | Node | Angular | Ionic | PHP | Laravel |
|---|---|---|---|---|---|
| Ayudando | 20 | 17 | 7 | 8.1 | 8 |
| Emergencias | 20 | 17 | 7 | 8.1 | 8 |
| Fiscalización | 22 | 20 | 8 | 8.1 | 8 |

> When upgrading Ayudando or Emergencias: follow the same pattern used for Fiscalización.
> See branch `feature/docker-node22-ng20` as reference implementation.

---

## Architecture Decisions

**Two-layer stack**: shared infrastructure (postgres, pgadmin, dashboard) + per-project services.
Shared layer uses `docker-compose.shared.yml`. Projects use `docker-compose.<project>.yml`.

**DB dump format**: `.tar` (not `.sql`). Import uses `pg_restore --no-owner --no-acl`, not `psql`.
File: `src/<project>/<project>.tar`.

**Dashboard health checks**: The dashboard nginx uses `entrypoint.sh` to detect the host gateway IP
at startup (`ip route show default`). This avoids the `host.docker.internal` IPv6 resolution bug on
Docker Desktop for Windows. Config template: `docker/dashboard/nginx.conf.template`.

**node_modules isolation**: Frontend `node_modules` live in a named Docker volume, NOT bind-mounted.
Avoids Windows bind-mount performance issues with 50k+ npm files.

**File upload limits**: All tuned to 500 MB across nginx and PHP. Timeout 600s everywhere.
See `docker/nginx/nginx.conf` and `docker/php/php.ini`.

**Frontend polling**: `ng serve` runs with `--poll 1000` for Windows file-change detection.

**Entrypoints auto-setup**:
- Backend (`docker/php/entrypoint.sh`): runs `composer install`, `artisan storage:link` on first start.
- Frontend (`docker/frontend/entrypoint.sh`): runs `npm install --legacy-peer-deps` then `ng serve`.
- Dashboard (`docker/dashboard/entrypoint.sh`): resolves host IP, renders nginx config, starts nginx.

---

## Required `.env` Variables

```
POSTGRES_PASSWORD
PGADMIN_PASSWORD
AYUDANDO_APP_KEY       # docker exec ayudando_backend php artisan key:generate
AYUDANDO_JWT_SECRET
AYUDANDO_MAIL_HOST
AYUDANDO_MAIL_USERNAME
AYUDANDO_MAIL_PASSWORD
# Same pattern for EMERGENCIAS_ and FISCALIZACION_
```

---

## Troubleshooting

**Backend can't reach DB**: `docker compose -f docker-compose.shared.yml ps` — `shared_postgres` must show `(healthy)`.
Root cause is usually missing `POSTGRES_PASSWORD` in `.env`.

**Composer fails in container**: `docker exec -it ayudando_backend sh` → `composer install --ignore-platform-reqs -vvv`.

**pgAdmin can't connect**: host must be `postgres` (service name), port `5432` (internal), Maintenance DB: `postgres`.

**Port conflict**: override in `.env` — `AYUDANDO_NGINX_PORT`, `AYUDANDO_FRONTEND_PORT`, etc.

**Frontend changes not detected**: `docker compose -f docker-compose.ayudando.yml --project-name ayudando restart frontend`.

**Dashboard shows all inactive**: project containers are not running, or restart the dashboard:
`docker compose -f docker-compose.shared.yml restart dashboard`.
