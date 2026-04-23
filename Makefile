.PHONY: up down restart logs ps build shell-backend shell-frontend artisan db-import

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
