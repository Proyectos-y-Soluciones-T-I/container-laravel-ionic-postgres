# Docker Hub user — override: make build-multi DOCKERHUB_USER=myuser
DOCKERHUB_USER ?= your-dockerhub-user
VERSION        ?= latest

BACKEND_IMAGE  = $(DOCKERHUB_USER)/ayudando-backend
FRONTEND_IMAGE = $(DOCKERHUB_USER)/ayudando-frontend

.PHONY: up down restart logs ps build shell-backend shell-frontend artisan db-import \
        buildx-setup build-multi push-multi

up:
	docker compose up -d

down:
	docker compose down

restart:
	docker compose restart

build:
	docker compose build --no-cache

logs:
	docker compose logs -f

ps:
	docker compose ps

shell-backend:
	docker exec -it ayudando_backend sh

shell-frontend:
	docker exec -it ayudando_frontend sh

shell-db:
	docker exec -it ayudando_postgres psql -U postgres -d ayudando

# Usage: make artisan cmd="migrate --seed"
artisan:
	docker exec ayudando_backend php artisan $(cmd)

# Import TAR dump: make db-import
db-import:
	docker exec -i ayudando_postgres pg_restore -U postgres -d ayudando --no-owner --no-acl < ayudando/ayudando.tar

migrate:
	docker exec ayudando_backend php artisan migrate

fresh:
	docker exec ayudando_backend php artisan migrate:fresh --seed

cache-clear:
	docker exec ayudando_backend php artisan config:clear
	docker exec ayudando_backend php artisan cache:clear
	docker exec ayudando_backend php artisan route:clear

cache-warm:
	docker exec ayudando_backend php artisan config:cache
	docker exec ayudando_backend php artisan route:cache

# ─── Multi-arch build (Docker Hub) ───────────────────────────────────────────
buildx-setup:
	docker buildx create --name ayudando-builder --use --bootstrap 2>/dev/null || \
	docker buildx use ayudando-builder

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
