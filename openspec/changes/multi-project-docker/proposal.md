# Proposal: Multi-Project Docker Compose

## Intent

The repo is hardcoded to a single project (`ayudando`). Adding a second project (e.g., `emergencias`, `fiscalizacion`) requires duplicating the entire repo. This change makes the infrastructure reusable across N projects via a project selector pattern, eliminating duplication and port collisions.

## Scope

### In Scope
- `docker-compose.base.yml` — shared service definitions (postgres, pgadmin, backend, nginx, frontend)
- Per-project override files: `docker-compose.ayudando.yml`, `docker-compose.emergencias.yml`, `docker-compose.fiscalizacion.yml`
- Makefile updated: `make up PROJECT=ayudando`, `make down PROJECT=ayudando`, all targets parameterized
- Entrypoints updated to use `PROJECT` env var instead of hardcoded `[ayudando]` prefixes
- `nginx/default.conf` templated to use `PROJECT`-derived upstream names
- `.gitignore` updated: `ayudando/` → `src/*/`
- `docker/dashboard/` — static HTML page listing all projects with port links
- Port allocation documented: ayudando=8080/4200/5432/5050, emergencias=8081/4201/5433/5051, fiscalizacion=8082/4202/5434/5052
- `src/` directory assumed pre-existing with `src/ayudando/` already moved by user

### Out of Scope
- Migrating `ayudando/` to `src/ayudando/` (user does this manually)
- Shared Redis service (deferred)
- CI/CD pipeline changes
- Application code changes inside `src/*/`

## Capabilities

### New Capabilities
- `multi-project-compose`: select and run any project via `PROJECT=<name>` make targets
- `project-dashboard`: static HTML launcher listing all registered projects with port links

### Modified Capabilities
None

## Approach

Per-project compose override pattern (same as `docker-compose.gpu.yml` already in repo):
1. `docker-compose.base.yml` defines services with `${PROJECT}` variable substitution for names, volumes, and networks
2. Per-project files set `PROJECT`, ports, and any project-specific overrides
3. Makefile resolves `PROJECT` → correct `-f` flags and passes env
4. Entrypoints read `PROJECT` env var for log prefixes and path resolution
5. nginx conf uses `${PROJECT}_backend` as upstream name (envsubst at container start)

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `docker-compose.yml` | Modified | Refactored into base + per-project files |
| `docker-compose.gpu.yml` | Modified | Updated to use new base file |
| `Makefile` | Modified | All targets gain `PROJECT=` parameter |
| `docker/php/entrypoint.sh` | Modified | Replace hardcoded `[ayudando]` with `$PROJECT` |
| `docker/frontend/entrypoint.sh` | Modified | Replace hardcoded prefix with `$PROJECT` |
| `docker/nginx/default.conf` | Modified | Upstream name uses `${PROJECT}_backend` |
| `.gitignore` | Modified | `ayudando/` → `src/*/` |
| `docker/dashboard/` | New | Static HTML project launcher |
| `docker-compose.ayudando.yml` | New | Port + env config for ayudando |
| `docker-compose.emergencias.yml` | New | Port + env config for emergencias |
| `docker-compose.fiscalizacion.yml` | New | Port + env config for fiscalizacion |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Port collisions if two projects run simultaneously | Low | Documented static port map; Makefile warns if ports in use |
| `envsubst` not available in all base images | Low | Add explicit install in Dockerfile or use sed fallback |
| Existing `.env` references `ayudando/` paths | Med | `.env.example` updated; migration note in README |

## Rollback Plan

`docker-compose.yml` is not deleted — it remains functional. If the new pattern breaks, run `docker compose -f docker-compose.yml up -d` directly. Per-project files are additive; no existing file is removed.

## Dependencies

- User must manually move `ayudando/` → `src/ayudando/` before running `make up PROJECT=ayudando`
- Docker Compose v2 (plugin syntax) — already in use

## Success Criteria

- [ ] `make up PROJECT=ayudando` starts all ayudando containers without error
- [ ] `make up PROJECT=emergencias` starts all emergencias containers on distinct ports with no collision
- [ ] Two projects can run simultaneously without container name or port conflicts
- [ ] `docker/dashboard/index.html` opens in browser and shows correct links for all projects
- [ ] `.gitignore` ignores `src/ayudando/` and `src/emergencias/`
