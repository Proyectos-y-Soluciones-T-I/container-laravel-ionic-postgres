# ─── Project selector ─────────────────────────────────────────────────────────
# Valid projects: ayudando, emergencias, fiscalizacion
# Usage: make up PROJECT=ayudando    (defaults to ayudando)
PROJECT ?= ayudando

VALID_PROJECTS := ayudando emergencias fiscalizacion

# ─── Compose files (base + per-project override) ──────────────────────────────
COMPOSE_CMD = docker compose -f docker-compose.base.yml -f docker-compose.$(PROJECT).yml --project-name $(PROJECT)

# ─── Docker Hub user — override: make build-multi DOCKERHUB_USER=myuser ───────
DOCKERHUB_USER ?= your-dockerhub-user
VERSION        ?= latest

BACKEND_IMAGE  = $(DOCKERHUB_USER)/ayudando-backend
FRONTEND_IMAGE = $(DOCKERHUB_USER)/ayudando-frontend

.PHONY: help guard-project up up-gpu up-no-gpu down down-gpu restart logs ps \
        shell-backend shell-frontend shell-db artisan \
        db-import migrate fresh cache-clear cache-warm \
        gpu-check mem-stats logs-slow \
        setup \
        buildx-setup build-backend-multi build-frontend-multi build-multi

# ─── Help ────────────────────────────────────────────────────────────────────
help: guard-project
	@echo ""
	@echo "╔══════════════════════════════════════════════════════════════╗"
	@echo "║                                                              ║"
	@echo "║   $(PROJECT) — Docker Compose Commands                       ║"
	@echo "║                                                              ║"
	@echo "╚══════════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "Uso: make <target> PROJECT=$(PROJECT)"
	@echo ""
	@echo "┌─────────────────────┬────────────────────────────────────────────────────────────┐"
	@echo "│ make target         │ docker compose equivalente                                  │"
	@echo "├─────────────────────┼────────────────────────────────────────────────────────────┤"
	@echo "│ make up             │ $(COMPOSE_CMD) up -d                                       │"
	@echo "│ make down           │ $(COMPOSE_CMD) down                                         │"
	@echo "│ make build          │ $(COMPOSE_CMD) build --no-cache                             │"
	@echo "│ make logs           │ $(COMPOSE_CMD) logs -f                                      │"
	@echo "│ make ps             │ $(COMPOSE_CMD) ps                                           │"
	@echo "│ make restart        │ $(COMPOSE_CMD) restart                                      │"
	@echo "├─────────────────────┼────────────────────────────────────────────────────────────┤"
	@echo "│ make shell-backend  │ docker exec -it $(PROJECT)_backend sh                       │"
	@echo "│ make shell-frontend │ docker exec -it $(PROJECT)_frontend sh                      │"
	@echo "│ make shell-db       │ docker exec -it $(PROJECT)_postgres psql -U postgres         │"
	@echo "├─────────────────────┼────────────────────────────────────────────────────────────┤"
	@echo "│ make artisan        │ docker exec $(PROJECT)_backend php artisan <cmd>             │"
	@echo "│ make migrate        │ docker exec $(PROJECT)_backend php artisan migrate           │"
	@echo "│ make fresh          │ docker exec $(PROJECT)_backend php artisan migrate:fresh --seed │"
	@echo "│ make cache-clear    │ docker exec $(PROJECT)_backend php artisan config:clear      │"
	@echo "│ make cache-warm     │ docker exec $(PROJECT)_backend php artisan config:cache      │"
	@echo "├─────────────────────┼────────────────────────────────────────────────────────────┤"
	@echo "│ make db-import      │ docker exec -i $(PROJECT)_postgres pg_restore -U postgres    │"
	@echo "│                     │   -d $(PROJECT) --no-owner --no-acl < src/$(PROJECT)/$(PROJECT).tar │"
	@echo "├─────────────────────┼────────────────────────────────────────────────────────────┤"
	@echo "│ make up-gpu         │ $(COMPOSE_CMD) up -d + GPU overlay                          │"
	@echo "│ make down-gpu       │ $(COMPOSE_CMD) down + clean GPU override                    │"
	@echo "│ make up-no-gpu      │ $(COMPOSE_CMD) up -d without GPU                            │"
	@echo "├─────────────────────┼────────────────────────────────────────────────────────────┤"
	@echo "│ make gpu-check      │ docker exec $(PROJECT)_backend nvidia-smi                    │"
	@echo "│ make mem-stats      │ docker stats --no-stream                                    │"
	@echo "│ make logs-slow      │ docker logs $(PROJECT)_postgres | grep duration:             │"
	@echo "└─────────────────────┴────────────────────────────────────────────────────────────┘"
	@echo ""
	@echo "Variables de entorno (copiar .env.example a .env y completar):"
	@echo "  PROJECT=$(PROJECT)"
	@echo "  $(PROJECT:%=%_POSTGRES_PASSWORD)"
	@echo "  $(PROJECT:%=%_PGADMIN_PASSWORD)"
	@echo "  $(PROJECT:%=%_APP_KEY)"
	@echo "  $(PROJECT:%=%_JWT_SECRET)"
	@echo "  $(PROJECT:%=%_MAIL_HOST)"
	@echo "  $(PROJECT:%=%_MAIL_USERNAME)"
	@echo "  $(PROJECT:%=%_MAIL_PASSWORD)"
	@echo ""
	@echo "Puertos de $(PROJECT):"
	@echo "  Nginx:     $$(grep "^$(PROJECT:%=%_NGINX_PORT)" .env 2>/dev/null | cut -d= -f2 || echo "ver .env.example")"
	@echo "  Frontend:  $$(grep "^$(PROJECT:%=%_FRONTEND_PORT)" .env 2>/dev/null | cut -d= -f2 || echo "ver .env.example")"
	@echo "  PostgreSQL: $$(grep "^$(PROJECT:%=%_POSTGRES_PORT)" .env 2>/dev/null | cut -d= -f2 || echo "ver .env.example")"
	@echo "  pgAdmin:   $$(grep "^$(PROJECT:%=%_PGADMIN_PORT)" .env 2>/dev/null | cut -d= -f2 || echo "ver .env.example")"
	@echo ""

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

# ─── Interactive setup (with optional @ngx-formly prompt) ────────────────────
setup: guard-project
	@bash scripts/setup.sh $(PROJECT)

# ─── Lifecycle ────────────────────────────────────────────────────────────────

# docker-compose.override.yml is auto-merged by Docker Compose — no -f flags needed.
# If it exists (GPU machine), GPU is active. If not, vanilla mode.
up: guard-project
	$(COMPOSE_CMD) up -d

up-gpu: guard-project
	cp docker-compose.gpu.yml docker-compose.override.yml
	$(COMPOSE_CMD) up -d

up-no-gpu: guard-project
	rm -f docker-compose.override.yml
	$(COMPOSE_CMD) up -d

down: guard-project
	$(COMPOSE_CMD) down

down-gpu: guard-project
	$(COMPOSE_CMD) down
	rm -f docker-compose.override.yml

restart: guard-project
	$(COMPOSE_CMD) restart

build: guard-project
	$(COMPOSE_CMD) build --no-cache

logs: guard-project
	$(COMPOSE_CMD) logs -f

ps: guard-project
	$(COMPOSE_CMD) ps

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
