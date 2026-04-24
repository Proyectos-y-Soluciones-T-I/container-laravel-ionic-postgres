# Docker Infrastructure

Full-stack Docker environment for the **Ayudando** project.

- **Backend**: Laravel 8 via PHP 8.0-FPM + Nginx 1.25
- **Frontend**: Ionic CLI 7 / Angular CLI 17 on Node 18
- **Database**: PostgreSQL 14.22

---

## Images

| Image | Platforms | Description |
|-------|-----------|-------------|
| `youruser/ayudando-backend` | `linux/amd64` `linux/arm64` `linux/arm/v7` | PHP 8.0-FPM with Laravel extensions |
| `youruser/ayudando-frontend` | `linux/amd64` `linux/arm64` | Node 18 + Ionic CLI 7 + Angular CLI 17 |

> **Note**: `linux/arm/v7` is available for the backend only. Node 18 dropped official 32-bit ARM support.

---

## Quick Start

```bash
# 1. Clone the infrastructure repo
git clone https://github.com/youruser/docker-li-container.git
cd docker-li-container

# 2. Clone the app source alongside (never committed here)
git clone https://github.com/youruser/project.git

# 3. Configure secrets
cp .env.example .env
# Fill in: POSTGRES_PASSWORD, PGADMIN_PASSWORD, APP_KEY, JWT_SECRET, MAIL_*

# 4. Start
docker compose up -d --build

# 5. Import database
make db-import
```

---

## Services

| Container | Port | Role |
|-----------|------|------|
| `ayudando_postgres` | 5432 | PostgreSQL 14 |
| `ayudando_pgadmin` | 5050 | pgAdmin 7.3 web UI |
| `ayudando_backend` | — | PHP-FPM (consumed by Nginx) |
| `ayudando_nginx` | 8080 | Laravel API reverse proxy |
| `ayudando_frontend` | 4200 | Angular dev server |

---

## Required Environment Variables

Copy `.env.example` and fill in these values:

```dotenv
# Database
POSTGRES_PASSWORD=           # required
POSTGRES_DB=ayudando
POSTGRES_USER=postgres

# pgAdmin
PGADMIN_PASSWORD=            # required

# Laravel
APP_KEY=                     # php artisan key:generate
JWT_SECRET=                  # required

# Mail
MAIL_HOST=
MAIL_USERNAME=
MAIL_PASSWORD=
```

---

## Common Commands

```bash
make up              # start all services
make down            # stop all services
make logs            # follow logs
make db-import       # import ayudando.tar dump
make migrate         # run Laravel migrations
make shell-backend   # sh into PHP container
make shell-frontend  # sh into Node container
make cache-clear     # clear Laravel caches
```

---

## Multi-Arch Build (local)

```bash
# Build and push all images
make build-multi DOCKERHUB_USER=youruser VERSION=1.0.0
```

---

## Troubleshooting

**Backend can't reach DB** — wait for postgres healthcheck: `docker compose ps`

**pgAdmin can't connect** — use host `postgres`, port `5432` (internal service name, not `localhost`)

**Frontend slow first start** — Angular compiles on first run (~60s). Subsequent restarts use the persistent `.angular` cache volume and are much faster.

**Port conflict** — override in `.env`: `NGINX_PORT`, `FRONTEND_PORT`, `PGADMIN_PORT`, `POSTGRES_PORT`
