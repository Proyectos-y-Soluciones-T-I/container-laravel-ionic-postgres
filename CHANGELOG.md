# Changelog

All notable changes to this project will be documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [Unreleased] — feature/multi-project → multi-project

### Added
- `scripts/setup.sh` — interactive host-side prompt that asks whether to extract `@ngx-formly.zip` before running `docker compose up -d`.
- `make setup PROJECT=<project>` — Makefile shortcut for the setup script.
- `MOBILE_BUILD.md` — full Android/iOS production build guide: prepare, build, sign (jarsigner + zipalign per project), Xcode archive, and pre-publish checklist.
- `@ngx-formly.zip` — local package bundle committed to the repo root for offline installation.

### Changed
- `docker/frontend/Dockerfile` — added `unzip` to the Alpine `apk` install.
- `docker/frontend/entrypoint.sh` — extracts `@ngx-formly` from the mounted zip when `INSTALL_FORMLY=yes` and the package is not yet installed.
- `docker-compose.ayudando.yml` / `emergencias.yml` / `fiscalizacion.yml` — added read-only bind mount for `@ngx-formly.zip` at `/tmp/ngx-formly.zip` and `INSTALL_FORMLY` env var (default: `no`).

---

## [2.0.0] — multi-project baseline

### Added
- Multi-project Docker Compose support: `docker-compose.ayudando.yml`, `docker-compose.emergencias.yml`, `docker-compose.fiscalizacion.yml`.
- Shared infrastructure layer: `docker-compose.shared.yml` — single PostgreSQL 14, pgAdmin 7 and dashboard shared across all projects.
- Dev dashboard (`docker/dashboard/`) — real-time health checks with per-project status cards at `http://localhost:8090`.
- Dashboard `entrypoint.sh` resolves host gateway IP at startup to avoid IPv6 issues on Docker Desktop for Windows.
- Redis 7 per project for session and cache management.
- GPU overlay support via `docker-compose.gpu.yml`.
- `Makefile` with full set of targets: lifecycle, shell, artisan, db-import, diagnostics, multi-arch build.
- Per-project env prefix convention (`AYUDANDO_`, `EMERGENCIAS_`, `FISCALIZACION_`) in `.env`.
- `DOCKER_HUB.md` — Docker Hub description source used by the publish workflow.
- `.github/workflows/docker-publish.yml` — multi-arch build and push to Docker Hub.
- `.gitattributes` — enforces LF line endings for shell scripts and Docker files.

### Changed
- `docker/frontend/entrypoint.sh` — runs `npm install` only when `node_modules/.bin/ng` is absent (idempotent restarts).
- `docker/php/entrypoint.sh` — auto-runs `composer install` and `artisan storage:link` on first start.
- PHP and Nginx tuned to 500 MB upload limit and 600 s timeout across all projects.
- `node_modules` isolated in a named Docker volume (avoids Windows bind-mount performance issues with 50 k+ files).
- `ng serve` runs with `--poll 1000` for reliable file-change detection on Windows.
- README rewritten with Docker commands as primary; `make` documented as optional shortcut.

### Fixed
- Dashboard health check IPv6 failure on Docker Desktop for Windows — resolved by detecting the host gateway IP with `ip route show default` at container start.
- Mail configuration updated to Gmail SMTP (port 587, TLS).
- Docker Hub readme filepath in CI workflow.

---

## [1.0.0] — individual project baseline

### Added
- Initial Docker setup for Ayudando: PHP 8.1-FPM, Nginx, Node 18, PostgreSQL 14, Redis.
- GPU support and optimized memory limits for backend and frontend.
- pgAdmin integration with connection instructions.
- Background queue worker in PHP entrypoint.

---

[Unreleased]: https://github.com/Proyectos-y-Soluciones-T-I/container-laravel-ionic-postgres/compare/multi-project...feature/multi-project
[2.0.0]: https://github.com/Proyectos-y-Soluciones-T-I/container-laravel-ionic-postgres/compare/individual...multi-project
[1.0.0]: https://github.com/Proyectos-y-Soluciones-T-I/container-laravel-ionic-postgres/commits/individual
