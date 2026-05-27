# ─── Project selector ─────────────────────────────────────────────────────────
# Valid projects: ayudando, emergencias, fiscalizacion
# Usage: make up PROJECT=ayudando    (defaults to ayudando)
PROJECT ?= ayudando

VALID_PROJECTS := ayudando emergencias fiscalizacion

# ─── Compose files (base + per-project override) ──────────────────────────────
COMPOSE_BASE     := -f docker-compose.base.yml
COMPOSE_PROJECT  := -f docker-compose.$(PROJECT).yml
COMPOSE_FILES    := $(COMPOSE_BASE) $(COMPOSE_PROJECT)

# ─── Docker Hub user — override: make build-multi DOCKERHUB_USER=myuser ───────
DOCKERHUB_USER ?= your-dockerhub-user
VERSION        ?= latest

BACKEND_IMAGE  = $(DOCKERHUB_USER)/ayudando-backend
FRONTEND_IMAGE = $(DOCKERHUB_USER)/ayudando-frontend

.PHONY: guard-project up up-gpu up-no-gpu down down-gpu restart logs ps build \
        shell-backend shell-frontend shell-db artisan \
        db-import migrate fresh cache-clear cache-warm \
        gpu-check mem-stats logs-slow \
        buildx-setup build-backend-multi build-frontend-multi build-multi

# ─── Guard ────────────────────────────────────────────────────────────────────
guard-project:
	@found=0; \
	for v in $(VALID_PROJECTS); do \
		if [ "$(PROJECT)" = "$$v" ]; then found=1; break; fi; \
	done; \
	if [ "$$found" != "1" ]; then \
		echo "Error: PROJECT must be one of: $(VALID_PROJECTS)"; \
		echo "  make up PROJECT=ayudando"; \
		echo "  make up PROJECT=emergencias"; \
		echo "  make up PROJECT=fiscalizacion"; \
		exit 1; \
	fi

# ─── Lifecycle ────────────────────────────────────────────────────────────────

# docker-compose.override.yml is auto-merged by Docker Compose — no -f flags needed.
# If it exists (GPU machine), GPU is active. If not, vanilla mode.
up: guard-project
	docker compose $(COMPOSE_FILES) --project-name $(PROJECT) up -d

up-gpu: guard-project
	cp docker-compose.gpu.yml docker-compose.override.yml
	docker compose $(COMPOSE_FILES) --project-name $(PROJECT) up -d

up-no-gpu: guard-project
	rm -f docker-compose.override.yml
	docker compose $(COMPOSE_FILES) --project-name $(PROJECT) up -d

down: guard-project
	docker compose $(COMPOSE_FILES) --project-name $(PROJECT) down

down-gpu: guard-project
	docker compose $(COMPOSE_FILES) --project-name $(PROJECT) down
	rm -f docker-compose.override.yml

restart: guard-project
	docker compose $(COMPOSE_FILES) --project-name $(PROJECT) restart

build: guard-project
	docker compose $(COMPOSE_FILES) --project-name $(PROJECT) build --no-cache

logs: guard-project
	docker compose $(COMPOSE_FILES) --project-name $(PROJECT) logs -f

ps: guard-project
	docker compose $(COMPOSE_FILES) --project-name $(PROJECT) ps

# ─── Container shell ──────────────────────────────────────────────────────────

shell-backend: guard-project
	docker exec -it $(PROJECT)_backend sh

shell-frontend: guard-project
	docker exec -it $(PROJECT)_frontend sh

shell-db: guard-project
	docker exec -it $(PROJECT)_postgres psql -U postgres -d $(PROJECT)

# Usage: make artisan cmd="migrate --seed"
artisan: guard-project
	docker exec $(PROJECT)_backend php artisan $(cmd)

# Import TAR dump: make db-import
db-import: guard-project
	docker exec -i $(PROJECT)_postgres pg_restore -U postgres -d $(PROJECT) --no-owner --no-acl < src/$(PROJECT)/$(PROJECT).tar

migrate: guard-project
	docker exec $(PROJECT)_backend php artisan migrate

fresh: guard-project
	docker exec $(PROJECT)_backend php artisan migrate:fresh --seed

cache-clear: guard-project
	docker exec $(PROJECT)_backend php artisan config:clear
	docker exec $(PROJECT)_backend php artisan cache:clear
	docker exec $(PROJECT)_backend php artisan route:clear

cache-warm: guard-project
	docker exec $(PROJECT)_backend php artisan config:cache
	docker exec $(PROJECT)_backend php artisan route:cache

# ─── Diagnóstico de rendimiento y GPU ────────────────────────────────────────

# Verify GPU is accessible inside the backend container (requires make up-gpu first)
gpu-check: guard-project
	docker exec $(PROJECT)_backend nvidia-smi

# Memory usage per container — shows current RSS and % of limit
mem-stats:
	docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.CPUPerc}}"

# Show slow queries logged by PostgreSQL (queries taking >200ms)
logs-slow: guard-project
	docker logs $(PROJECT)_postgres 2>&1 | grep "duration:"

# ─── Multi-arch build (Docker Hub) ───────────────────────────────────────────
buildx-setup: guard-project
	docker buildx create --name $(PROJECT)-builder --use --bootstrap 2>/dev/null || \
	docker buildx use $(PROJECT)-builder

# Build + push backend (amd64 / arm64 / arm/v7)
build-backend-multi: buildx-setup
	docker buildx build \
	    --platform linux/amd64,linux/arm64,linux/arm/v7 \
	    --tag $(BACKEND_IMAGE):$(VERSION) \
	    --file docker/php/Dockerfile \
	    --push .

# Build + push frontend (amd64 / arm64 — Node 18 dropped arm/v7 officially)
build-frontend-multi: buildx-setup
	docker buildx build \
	    --platform linux/amd64,linux/arm64 \
	    --tag $(FRONTEND_IMAGE):$(VERSION) \
	    --file docker/frontend/Dockerfile \
	    --push .

build-multi: build-backend-multi build-frontend-multi
