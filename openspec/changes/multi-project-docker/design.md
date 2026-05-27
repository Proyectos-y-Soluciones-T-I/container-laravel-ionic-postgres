# Design: Multi-Project Docker Compose

## Technical Approach

Replace hardcoded single-project compose with a **base + override** pattern — same mechanism already proven by `docker-compose.gpu.yml`. The `docker-compose.yml` becomes `docker-compose.base.yml`, templated with `${PROJECT}` for container names, bind mounts (`./src/${PROJECT}/server`), and network. Per-project override files (`docker-compose.ayudando.yml`, etc.) inject `PROJECT`, port overrides, and project-specific env vars.

Two projects can run simultaneously because each gets its own Docker Compose project name, network, and volumes — no collisions.

## Architecture Decisions

| # | Decision | Options | Tradeoff | Choice |
|---|----------|---------|----------|--------|
| 1 | **Base + override vs single parameterized file** | A) `base.yml` + per-project `override.yml`<br>B) Single `docker-compose.yml` with `${PROJECT}` from env | A: more files but explicit per-project port/config isolation; B: simpler but all projects share identical structure | **A** — base+override mirrors existing `docker-compose.gpu.yml` pattern; per-project files are self-documenting for port allocation |
| 2 | **envsubst vs per-project nginx confs** | A) `envsubst` at container start<br>B) Per-project static confs<br>C) Identical conf for all projects (no change needed) | A: adds alpine dependency; B: duplicates identical configs; C: zero duplication, zero runtime cost | **C** — nginx `default.conf` is identical across projects because `backend:9000` resolves within each project's isolated network. `root /var/www/html/public` is the same internal path. No templating needed |
| 3 | **Dashboard: container vs static HTML** | A) Standalone nginx container on port 80<br>B) Static HTML served from running project's nginx<br>C) Static HTML file only, user opens in browser | A: extra container + port; B: tied to one project being up; C: simplest, no infra | **C** — `docker/dashboard/index.html` with hardcoded links. Optionally add `/dashboard` nginx location later. No container |
| 4 | **Volume naming** | A) `${PROJECT}_` prefix in compose file<br>B) Rely on `docker compose --project-name` autoprefix | A: explicit but verbose; B: automatic via Docker Compose (e.g., `ayudando_postgres_data`) | **B** — Docker Compose already scopes volumes by project name. Declare `postgres_data` in base, runtime name becomes `{project}_postgres_data` |
| 5 | **Network naming** | A) Explicit `${PROJECT}_net`<br>B) Compose default `{project}_default` | A: consistent with current `ayudando_net` pattern; B: zero config | **A** — explicit name matches existing convention and is grep-friendly. Simultaneous runs work because networks are project-scoped |
| 6 | **Makefile: PROJECT flow** | A) `docker compose -f base.yml -f {project}.yml --project-name {project}`<br>B) `PROJECT=ayudando docker compose --project-name ayudando up` | A: explicit file selection, matches override pattern; B: simpler but all projects share single compose file | **A** — aligns with decision 1; Makefile resolves PROJECT → correct `-f` flags and passes env |

## Data Flow

```
User: make up PROJECT=ayudando
  │
  ▼
Makefile resolves:
  PROJECT=ayudando
  COMPOSE_FILES=-f docker-compose.base.yml -f docker-compose.ayudando.yml
  docker compose $(COMPOSE_FILES) --project-name ayudando up -d
  │
  ├── PROJECT=ayudando injected as env var to all containers
  ├── Network: ayudando_net (isolated)
  ├── Volumes: ayudando_postgres_data, ayudando_frontend_node_modules, ...
  │
  ▼
entrypoint.sh reads $PROJECT → log prefix "[ayudando]", paths under /var/www/html
nginx resolves backend:9000 within ayudando_net → FPM on :9000
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `docker-compose.yml` | Rename → `docker-compose.base.yml` | Parameterize with `${PROJECT}` for container_name, bind mounts, network; remove hardcoded `ayudando_` prefixes |
| `docker-compose.base.yml` | Create (rename) | See above — port vars `${NGINX_PORT:-8080}`, bind mounts `./src/${PROJECT}/server` |
| `docker-compose.ayudando.yml` | Create | Override: `PROJECT=ayudando`, ports 8080/4200/5432/5050 |
| `docker-compose.emergencias.yml` | Create | Override: `PROJECT=emergencias`, ports 8081/4201/5433/5051 |
| `docker-compose.fiscalizacion.yml` | Create | Override: `PROJECT=fiscalizacion`, ports 8082/4202/5434/5052 |
| `docker-compose.gpu.yml` | Modify | Update `-f` references to base file |
| `Makefile` | Modify | All targets parameterized with `PROJECT=ayudando` default; `COMPOSE_FILES` resolved per project; container names use `${PROJECT}_` prefix |
| `docker/php/entrypoint.sh` | Modify | `[ayudando]` → `[$PROJECT]`; `composer install` / `artisan` paths remain same (WORKDIR unchanged) |
| `docker/frontend/entrypoint.sh` | Modify | `[ayudando]` → `[$PROJECT]`; `ng serve` port from `$FRONTEND_PORT` env var |
| `.gitignore` | Modify | `ayudando/` → `src/` (entire src dir ignored) |
| `.env.example` | Modify | Add `PROJECT=ayudando`; document per-project port table |
| `docker/dashboard/index.html` | Create | Static HTML with cards linking to all three projects' nginx + pgAdmin URLs |

## Interfaces / Contracts

**Makefile contract**:
```makefile
PROJECT ?= ayudando
COMPOSE_BASE := -f docker-compose.base.yml
COMPOSE_PROJECT := -f docker-compose.$(PROJECT).yml
COMPOSE_FILES := $(COMPOSE_BASE) $(COMPOSE_PROJECT)

up:
	docker compose $(COMPOSE_FILES) --project-name $(PROJECT) up -d
```

**Container env vars injected by compose override**:
- `PROJECT` — string, e.g. `ayudando`
- `NGINX_PORT`, `FRONTEND_PORT`, `POSTGRES_PORT`, `PGADMIN_PORT` — project-specific

**Entrypoint contract**: Read `$PROJECT` env var (fallback: `unknown`). No path logic change — WORKDIR remains `/var/www/html` (backend) and `/app` (frontend).

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Manual smoke | `make up PROJECT=ayudando` | Verify all 6 containers healthy, nginx serves app, frontend dev server accessible |
| Manual smoke | `make up PROJECT=emergencias` | Same checks on distinct ports (8081, 4201) |
| Collision | Both projects running simultaneously | `docker compose ps` — no container name or port conflicts |
| Dashboard | Open `docker/dashboard/index.html` | All links resolve to correct ports |
| Backward compat | `make up` (no PROJECT) | Defaults to `ayudando`, behaves identically to pre-change |

## Migration / Rollout

1. User moves `ayudando/` → `src/ayudando/` manually (one-time)
2. Run `make up PROJECT=ayudando` — same workflow, parameterized
3. Original `docker-compose.yml` is renamed to `docker-compose.base.yml` — the file is not deleted. Rollback: `docker compose -f docker-compose.base.yml -f docker-compose.ayudando.yml up -d` (functionally identical)
4. `.gitignore` change is non-destructive — previously untracked `src/` files remain untracked

## Open Questions

- [ ] Should `make down` also accept `PROJECT=` to stop a specific project without affecting others? (Recommended: yes — default stops all, `PROJECT=x` stops that project only)
