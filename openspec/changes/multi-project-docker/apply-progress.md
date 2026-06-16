# Apply Progress: Multi-Project Docker Compose

## Mode
- **TDD**: Disabled (Standard Mode)
- **Delivery**: feature-branch-chain (all phases in one batch to `feature/multi-project`)
- **Batch**: Phase 1 + Phase 2 + Phase 3 — all structural tasks completed

## Completed Tasks (13/16)

### Phase 1 — Compose Foundation
- [x] **1.1** Branch `feature/multi-project` — already existed, working on it
- [x] **1.2** `docker-compose.base.yml` — shared services (postgres, pgadmin, redis) with `${PROJECT}_` prefixes; per-project services kept out
- [x] **1.3** `docker-compose.ayudando.yml` — port 8080/4200/5432/5050, network `ayudando_net`
- [x] **1.4** `docker-compose.emergencias.yml` — port 8081/4201/5433/5051, network `emergencias_net`
- [x] **1.5** `docker-compose.fiscalizacion.yml` — port 8082/4202/5434/5052, network `fiscalizacion_net`
- [x] **1.6** `.gitignore` — `ayudando/` → `src/`
- [x] **1.7** Compose config validated — all 3 projects parse without errors

### Phase 2 — Makefile + Entrypoints
- [x] **2.1** Makefile — `PROJECT ?= ayudando`, `COMPOSE_FILES`, guard, parameterized up/down/build/logs/ps
- [x] **2.2** Makefile — parameterized shell/exec targets with `$(PROJECT)_` prefix
- [x] **2.3** Makefile — `db-import` uses `$(PROJECT)_postgres` and `src/$(PROJECT)/$(PROJECT).tar`
- [x] **2.4** `docker/php/entrypoint.sh` — all `[ayudando]` → `[$PROJECT]` with fallback
- [x] **2.5** `docker/frontend/entrypoint.sh` — all `[ayudando]` → `[$PROJECT]` with fallback
- [ ] **2.6** Runtime: `make up PROJECT=ayudando` smoke test *(manual — needs Docker)*

### Phase 3 — Dashboard + Polish
- [x] **3.1** `docker/dashboard/index.html` — static HTML cards for all 3 projects
- [x] **3.2** `.env.example` — added `PROJECT=ayudando` with port table
- [x] **3.3** `docker-compose.gpu.yml` — comment updated to reference base.yml
- [ ] **3.4** Smoke test: `make up PROJECT=ayudando` *(manual — needs Docker)*
- [ ] **3.5** Smoke test: `make up PROJECT=emergencias` *(manual — needs Docker + src)*
- [ ] **3.6** Dashboard visual verification *(manual — browser)*

## Files Changed

| File | Action | What Was Done |
|------|--------|---------------|
| `docker-compose.base.yml` | Created | Shared infra services (postgres, pgadmin, redis) with `${PROJECT}_` prefixes |
| `docker-compose.ayudando.yml` | Created | Per-project override: backend/nginx/frontend + ports 8080/4200/5432/5050 |
| `docker-compose.emergencias.yml` | Created | Per-project override: ports 8081/4201/5433/5051 |
| `docker-compose.fiscalizacion.yml` | Created | Per-project override: ports 8082/4202/5434/5052 |
| `docker/dashboard/index.html` | Created | Static dashboard HTML with project cards |
| `Makefile` | Modified | Parameterized ALL targets with `$(PROJECT)`, added guard |
| `.gitignore` | Modified | `ayudando/` → `src/` |
| `.env.example` | Modified | Added `PROJECT=ayudando` with port table |
| `docker/php/entrypoint.sh` | Modified | `[ayudando]` → `[$PROJECT]` with fallback |
| `docker/frontend/entrypoint.sh` | Modified | `[ayudando]` → `[$PROJECT]` with fallback |
| `docker-compose.gpu.yml` | Modified | Updated comment to reference base.yml |

## Deviations from Design

1. **Network definition location**: Design placed `networks: ${PROJECT}_net` in base.yml. Docker Compose does not support variable substitution in top-level `networks:` mapping keys (confirmed via test). Moved network definitions to each per-project override file with hardcoded names (`ayudando_net`, `emergencias_net`, `fiscalizacion_net`). All services in base.yml still reference `networks: ${PROJECT}_net` which resolves correctly.

2. **Volume names**: Design decision 4 chose project-name scoping (declare simple names, Docker prefixes them). This is preserved — `postgres_data` becomes `ayudando_postgres_data` at runtime.

3. **Task 1.2** changed from "Rename docker-compose.yml → docker-compose.base.yml" to "Create docker-compose.base.yml" — original docker-compose.yml remains for backward compatibility.

## Issues Found

- Docker Compose (version in use) does NOT support `${VAR}` substitution in top-level `networks:` key names. Services can reference `${PROJECT}_net` but the network cannot be *declared* with a variable. Workaround: per-project files declare the network explicitly.
- `db-import` target uses `src/$(PROJECT)/$(PROJECT).tar` (not `ayudando.tar`) for generic project support.

## Remaining Tasks

- [ ] **2.6** Runtime: start Docker, run `make up PROJECT=ayudando`, verify containers
- [ ] **3.4-3.6** Smoke tests and dashboard verification

## Status
**13/16 tasks complete.** Ready for runtime verification (Docker must be running).
