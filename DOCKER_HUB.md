# Ayudando — Docker Images

Docker infrastructure for the **Ayudando** project: Laravel 8 backend + Ionic/Angular 17 frontend running on PostgreSQL 14, Redis 7, and Nginx.

> Source repository: [github.com/ramirezDg/docker-li-container](https://github.com/ramirezDg/docker-li-container)

---

## Images

| Image | Platforms | Description |
|-------|-----------|-------------|
| `your-dockerhub-user/ayudando-backend` | linux/amd64, linux/arm64, linux/arm/v7 | PHP 8.1-FPM + all Laravel extensions + JIT |
| `your-dockerhub-user/ayudando-frontend` | linux/amd64, linux/arm64 | Node 18.16.1 + Ionic CLI 7 + Angular CLI 17 |

---

## Stack

| Service | Image | Role |
|---------|-------|------|
| `postgres` | postgres:14.22-alpine | Primary database |
| `redis` | redis:7-alpine | Sessions + cache (in-memory) |
| `backend` | ayudando-backend | Laravel 8 via PHP-FPM |
| `nginx` | nginx:1.25-alpine | Reverse proxy → FPM :9000 |
| `frontend` | ayudando-frontend | Angular/Ionic dev server |
| `pgadmin` | dpage/pgadmin4:7.3 | Database admin UI |

---

## Quick Start

### 1 — Clone the infrastructure repo

```bash
git clone https://github.com/ramirezDg/docker-li-container ayudando-docker
cd ayudando-docker
```

### 2 — Place the Ayudando project source

```bash
git clone <ayudando-project-url> ayudando
# Expected structure:
#   ayudando/server/       <- Laravel 8
#   ayudando/frontend/     <- Ionic/Angular 17
#   ayudando/ayudando.tar  <- PostgreSQL dump
```

### 3 — Configure environment

```bash
cp .env.example .env
# Edit .env — fill in POSTGRES_PASSWORD, APP_KEY, JWT_SECRET, MAIL_* credentials
```

### 4 — Build and start

```bash
# Without GPU:
make build && make up

# With NVIDIA GPU (requires NVIDIA Container Toolkit):
make build && make up-gpu
```

### 5 — Import database

```bash
make db-import
```

### 6 — Access

| URL | Service |
|-----|---------|
| http://localhost:8080 | Laravel API (via Nginx) |
| http://localhost:4200 | Angular/Ionic dev server |
| http://localhost:5050 | pgAdmin |

---

## Backend Image — `ayudando-backend`

**Base**: `php:8.1.17-fpm-alpine` (multi-stage — no build tools in final image)

**PHP extensions included:**
- `pdo`, `pdo_pgsql`, `pgsql` — PostgreSQL
- `gd` — Image processing (freetype + libjpeg)
- `zip`, `bcmath`, `intl`, `mbstring`, `exif`, `pcntl` — Laravel requirements
- `opcache` — With JIT (trampoline mode) enabled
- `redis` (phpredis) — Native Redis client for sessions/cache

**Performance features:**
- OPcache JIT enabled (`opcache.jit=trampoline`) — speeds up CPU-bound paths
- `opcache.revalidate_freq=2` — avoids per-request `stat()` calls on bind mounts
- Sessions and cache via Redis (eliminates Windows file I/O bottleneck)
- PHP-FPM dynamic pool: 2 warm workers, scales to 10
- Config and route cache pre-built on container start (~300ms -> ~30ms bootstrap)
- 500 MB upload support (nginx + php.ini)

**Memory limit:** 320 MB (configurable in `docker-compose.yml`)

---

## Frontend Image — `ayudando-frontend`

**Base**: `node:18.16.1-alpine`

**Tools included:**
- Ionic CLI 7
- Angular CLI 17
- `npm` with `--legacy-peer-deps` support

**Performance features:**
- `node_modules` in a named Docker volume (avoids Windows bind-mount I/O for 50k+ files)
- Angular cache (`.angular`) in a named volume — incremental builds persist across restarts
- File change detection via polling (`--poll 1000`) for Windows/WSL2 compatibility
- Node.js heap capped at 1 GB (sufficient for Angular 17 incremental builds)

**Memory limit:** 2 GB (Angular full rebuild can spike; incremental stays under 512 MB)

---

## GPU Support (Optional)

GPU acceleration is optional and non-breaking — the stack runs identically without it.

**Requirements:**
- NVIDIA GPU
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html)
- WSL2 with NVIDIA CUDA support (Windows) or native Linux with NVIDIA drivers >= 470

**Enable GPU:**
```bash
make up-gpu
# or: docker compose -f docker-compose.yml -f docker-compose.gpu.yml up -d
```

**Disable GPU:**
```bash
make down-gpu && make up
```

**Verify GPU inside container:**
```bash
make gpu-check
# or: docker exec ayudando_backend nvidia-smi
```

The GPU overlay (`docker-compose.gpu.yml`) adds NVIDIA device reservation to the backend service only. All memory limits from the base compose are preserved.

---

## Environment Variables

### Required

| Variable | Description |
|----------|-------------|
| `POSTGRES_PASSWORD` | PostgreSQL root password |
| `PGADMIN_PASSWORD` | pgAdmin login password |
| `APP_KEY` | Laravel encryption key (`php artisan key:generate --show`) |
| `JWT_SECRET` | JWT signing secret (min 64 chars) |
| `MAIL_HOST` | SMTP server hostname |
| `MAIL_USERNAME` | SMTP auth user |
| `MAIL_PASSWORD` | SMTP auth password |

### Optional (with defaults)

| Variable | Default | Description |
|----------|---------|-------------|
| `POSTGRES_DB` | `ayudando` | Database name |
| `POSTGRES_USER` | `postgres` | Database user |
| `POSTGRES_PORT` | `5432` | Host-mapped DB port |
| `NGINX_PORT` | `8080` | Host-mapped API port |
| `FRONTEND_PORT` | `4200` | Host-mapped frontend port |
| `PGADMIN_PORT` | `5050` | Host-mapped pgAdmin port |
| `APP_ENV` | `local` | Laravel environment |
| `APP_DEBUG` | `true` | Laravel debug mode |

---

## Memory Budget (Idle)

| Container | Limit | Typical Idle RSS |
|-----------|-------|-----------------|
| postgres | 384 MB | ~150-200 MB |
| redis | 160 MB | ~5-10 MB |
| backend | 320 MB | ~120-160 MB |
| nginx | 64 MB | ~10-15 MB |
| pgadmin | 256 MB | ~80-150 MB |
| frontend | 2 GB | ~200-500 MB |

Check live usage:
```bash
make mem-stats
# or: docker stats --no-stream
```

---

## Useful Make Targets

```bash
make up             # start all services
make up-gpu         # start with NVIDIA GPU
make up-no-gpu      # start without GPU (cleans override)
make down           # stop all services
make down-gpu       # stop + remove GPU override
make build          # rebuild images (no cache)
make logs           # follow all logs
make ps             # container status

make shell-backend  # shell into PHP container
make shell-frontend # shell into Node container
make shell-db       # psql into PostgreSQL

make db-import      # restore from ayudando/ayudando.tar
make migrate        # php artisan migrate
make fresh          # php artisan migrate:fresh --seed
make cache-clear    # clear Laravel config/cache/routes
make cache-warm     # pre-cache config + routes

make gpu-check      # verify GPU access inside container
make mem-stats      # memory + CPU snapshot per container
make logs-slow      # show PostgreSQL queries > 200ms
```

---

## Building Multi-Arch Images

```bash
# Set your Docker Hub username
export DOCKERHUB_USER=youruser

# Build and push both images
make build-multi DOCKERHUB_USER=$DOCKERHUB_USER

# Or individually
make build-backend-multi  DOCKERHUB_USER=$DOCKERHUB_USER VERSION=1.0.0
make build-frontend-multi DOCKERHUB_USER=$DOCKERHUB_USER VERSION=1.0.0
```

Platforms: `linux/amd64`, `linux/arm64` (both), `linux/arm/v7` (backend only).

---

## Architecture Notes

- **DB dump format**: `.tar` — import with `pg_restore`, not `psql`
- **Sessions/Cache**: Redis (not file driver) — eliminates Windows bind-mount I/O bottleneck
- **node_modules**: Named Docker volume — avoids WSL2 bind-mount performance degradation for 50k+ npm files
- **PHP image**: Multi-stage build — build tools (gcc, make) not present in runtime image (~150 MB lighter)
- **OPcache**: `revalidate_freq=2` — avoids per-request `stat()` on bind-mounted PHP files
- **File uploads**: All limits set to 500 MB (nginx + php.ini + FastCGI buffers + 600s timeouts)
- **Slow query log**: PostgreSQL logs any query taking > 200ms — `make logs-slow` to inspect
