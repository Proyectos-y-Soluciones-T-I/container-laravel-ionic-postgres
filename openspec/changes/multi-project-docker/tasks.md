# Tasks: Multi-Project Docker Compose

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~380–430 |
| 400-line budget risk | Medium |
| Chained PRs recommended | Yes |
| Suggested split | PR 1 → PR 2 → PR 3 |
| Delivery strategy | feature-branch-chain |
| Chain strategy | feature-branch-chain |

Decision needed before apply: Yes (resolved: feature-branch-chain, all phases in one batch)
Chained PRs recommended: Yes
Chain strategy: feature-branch-chain — all commits to feature/multi-project
400-line budget risk: Medium

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Base + override compose files, .gitignore | PR 1 | Foundation — all other tasks depend on this. Base = `feature/multi-project` |
| 2 | Makefile + entrypoints | PR 2 | Wiring — depends on PR 1. Base = PR 1 branch |
| 3 | Dashboard + .env.example + gpu.yml + smoke test | PR 3 | Polish — depends on PR 2. Base = PR 2 branch |

---

## Phase 1: Compose Foundation

- [x] 1.1 Create `feature/multi-project` branch from current HEAD
- [x] 1.2 Create `docker-compose.base.yml`: extracted shared services (postgres, pgadmin, redis) with `${PROJECT}_` prefixes; per-project services (backend, nginx, frontend) kept out of base; network defined in per-project overrides due to docker compose variable limitation in top-level keys
- [x] 1.3 Create `docker-compose.ayudando.yml`: PROJECT=ayudando, ports 8080/4200/5432/5050, network ayudando_net
- [x] 1.4 Create `docker-compose.emergencias.yml`: PROJECT=emergencias, ports 8081/4201/5433/5051, network emergencias_net
- [x] 1.5 Create `docker-compose.fiscalizacion.yml`: PROJECT=fiscalizacion, ports 8082/4202/5434/5052, network fiscalizacion_net
- [x] 1.6 Update `.gitignore`: replaced `ayudando/` with `src/`
- [x] 1.7 Verify: `docker compose -f docker-compose.base.yml -f docker-compose.ayudando.yml config` parses without errors — all 3 projects validated

## Phase 2: Makefile + Entrypoints

- [x] 2.1 Update `Makefile`: added `PROJECT ?= ayudando` default, COMPOSE_FILES logic, guard-project target, parameterized up/down/build/logs/ps
- [x] 2.2 Update `Makefile`: parameterized shell-backend, shell-frontend, shell-db, artisan, migrate, fresh, cache-clear with `$(PROJECT)_` container prefix
- [x] 2.3 Update `Makefile`: fixed db-import to use `$(PROJECT)_postgres` and `src/$(PROJECT)/$(PROJECT).tar`
- [x] 2.4 Update `docker/php/entrypoint.sh`: replaced all `[ayudando]` log prefixes with `[$PROJECT]` (fallback: `unknown`)
- [x] 2.5 Update `docker/frontend/entrypoint.sh`: replaced all `[ayudando]` log prefixes with `[$PROJECT]`
- [ ] 2.6 Verify: `make up PROJECT=ayudando` starts all containers; `docker compose ps` shows `ayudando_` prefixed names *(runtime — needs Docker running)*

## Phase 3: Dashboard + Polish

- [x] 3.1 Create `docker/dashboard/index.html`: static HTML with cards for all 3 projects with correct port links
- [x] 3.2 Update `.env.example`: added `PROJECT=ayudando` line with per-project port table comment
- [x] 3.3 Update `docker-compose.gpu.yml`: updated comment to reference `docker-compose.base.yml`
- [ ] 3.4 Smoke test: `make up PROJECT=ayudando` → verify nginx:8080, frontend:4200 accessible *(runtime — needs Docker running and src/ayudando/ present)*
- [ ] 3.5 Smoke test: `make up PROJECT=emergencias` (with src/emergencias/ present) → verify ports 8081/4201 *(runtime — needs Docker + src)*
- [ ] 3.6 Verify dashboard: open `docker/dashboard/index.html` in browser, confirm all links correct *(visual — manual)*
