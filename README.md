# Ayudando — Entorno Docker

Repositorio de infraestructura Docker para el proyecto Ayudando.
El código fuente del proyecto (`ayudando/`) se coloca localmente y **nunca se modifica desde aquí**.

> **Regla fundamental**: todo cambio de configuración va en `docker/` o en la raíz de este repo. Nunca dentro de `ayudando/`.

---

## Índice

1. [Arquitectura](#arquitectura)
2. [Requisitos previos](#requisitos-previos)
3. [Configuración inicial (primera vez)](#configuración-inicial-primera-vez)
4. [Variables de entorno](#variables-de-entorno)
5. [Environment del frontend](#environment-del-frontend)
6. [Levantar el entorno](#levantar-el-entorno)
7. [Importar la base de datos](#importar-la-base-de-datos)
8. [URLs de acceso](#urls-de-acceso)
9. [Comandos del día a día](#comandos-del-día-a-día)
10. [Flujo de arranque automático](#flujo-de-arranque-automático)
11. [Soporte de archivos grandes](#soporte-de-archivos-grandes)
12. [Troubleshooting](#troubleshooting)

---

## Arquitectura

```
docker-li-container/          ← este repo
├── docker-compose.yml        ← define los 5 servicios
├── .env                      ← credenciales locales (NO commitear)
├── Makefile                  ← comandos rápidos
├── docker/
│   ├── php/                  ← PHP 8.0-FPM + extensiones Laravel
│   ├── nginx/                ← reverse proxy + soporte archivos grandes
│   └── frontend/             ← Node 18.16.1 + Ionic 7 + Angular 17
└── ayudando/                 ← proyecto fuente (ignorado por git)
    ├── server/               ← Laravel 8 (backend)
    ├── frontend/             ← Ionic/Angular 17 (frontend)
    └── ayudando.tar          ← dump inicial de la base de datos
```

### Servicios y puertos

| Contenedor          | Imagen                    | Puerto | Descripción                        |
|---------------------|---------------------------|--------|------------------------------------|
| `ayudando_postgres` | postgres:14.22-alpine     | 5432   | Base de datos PostgreSQL           |
| `ayudando_pgadmin`  | dpage/pgadmin4:7.3        | 5050   | Administrador visual de la BD      |
| `ayudando_backend`  | (build local) PHP 8.0-FPM | —      | Laravel 8 — expuesto via Nginx     |
| `ayudando_nginx`    | nginx:1.25-alpine         | 8080   | Proxy HTTP → PHP-FPM en puerto 9000|
| `ayudando_frontend` | (build local) Node 18     | 4200   | Ionic/Angular dev server           |

Todos los servicios comparten la red interna `ayudando_net`. La comunicación entre servicios usa los nombres de contenedor (ej: el backend se conecta a postgres usando el host `postgres`, no `localhost`).

---

## Requisitos previos

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) ≥ 4.x (con WSL2 habilitado en Windows)
- Git
- `make` (opcional pero recomendado — disponible con Git for Windows, Chocolatey o WSL)

Verificar instalación:

```bash
docker --version
docker compose version
```

---

## Configuración inicial (primera vez)

Seguir estos pasos **en orden exacto**.

### Paso 1 — Clonar este repositorio

```bash
git clone <url-de-este-repo> docker-li-container
cd docker-li-container
```

### Paso 2 — Colocar el proyecto Ayudando

El código fuente va en `ayudando/` dentro de esta carpeta. Git lo ignora completamente.

```bash
# Opción A: clonar el proyecto dentro de esta carpeta
git clone <url-del-proyecto-ayudando> ayudando

# Opción B: copiar manualmente la carpeta del proyecto aquí
```

Estructura esperada al finalizar:

```
docker-li-container/
└── ayudando/
    ├── server/          ← Laravel (backend)
    ├── frontend/        ← Ionic/Angular (frontend)
    └── ayudando.tar     ← dump de la base de datos
```

> Si el dump no se llama `ayudando.tar`, renombrarlo o ajustar el comando en el Paso 6.

### Paso 3 — Crear el archivo de variables de entorno

```bash
cp .env.example .env
```

Editar `.env` con las credenciales reales del equipo (ver sección [Variables de entorno](#variables-de-entorno)).

> **Nunca commitear `.env`** — está en `.gitignore`. Contiene contraseñas reales.

### Paso 4 — Verificar el environment del frontend

Abrir `ayudando/frontend/src/environments/environment.ts` y confirmar que las URLs apuntan a `localhost:8080`:

```typescript
export const environment = {
  production: false,
  baseUrl: "http://localhost:8080/api/",
  storageUrl: "http://localhost:8080/storage/",
  mapsApiKey: "TU_API_KEY_DE_GOOGLE_MAPS",
};
```

Si las URLs apuntan a producción u otro servidor, cambiarlas a `localhost:8080` para el entorno local. Ver sección [Environment del frontend](#environment-del-frontend) para más detalles.

### Paso 5 — Construir las imágenes y levantar

```bash
# Con make:
make build
make up

# Sin make:
docker compose build --no-cache
docker compose up -d
```

La primera construcción tarda varios minutos porque:
- Descarga imágenes base de Docker Hub
- Instala extensiones PHP (pdo_pgsql, gd, zip, bcmath, intl, exif, opcache)
- Instala Composer 2.5.8
- Instala Ionic CLI 7 y Angular CLI 17

### Paso 6 — Importar la base de datos

Esperar que el contenedor de postgres esté `(healthy)`:

```bash
docker compose ps
# ayudando_postgres debe mostrar (healthy)
```

Luego importar:

```bash
# Con make:
make db-import

# Sin make:
docker exec -i ayudando_postgres pg_restore -U postgres -d ayudando --no-owner --no-acl < ayudando/ayudando.tar
```

> El dump está en formato `.tar` — se importa con `pg_restore`, **no** con `psql`.

### Paso 7 — Verificar que todo esté corriendo

```bash
docker compose ps
```

Todos los contenedores deben mostrar `running` o `Up`. El frontend tarda unos minutos adicionales en compilar por primera vez.

Ver logs del frontend:

```bash
docker compose logs frontend -f
```

Esperar la línea:
```
✔ Compiled successfully.
```

---

## Variables de entorno

Copiar `.env.example` a `.env` y completar todos los valores. A continuación la referencia completa:

```env
# ─── Base de datos ────────────────────────────────────────────────────────────
POSTGRES_DB=ayudando
POSTGRES_USER=postgres
POSTGRES_PASSWORD=<contraseña segura>        # REQUERIDA
POSTGRES_PORT=5432

# ─── pgAdmin ──────────────────────────────────────────────────────────────────
PGADMIN_EMAIL=admin@ayudando.local
PGADMIN_PASSWORD=<contraseña segura>         # REQUERIDA
PGADMIN_PORT=5050

# ─── Laravel ──────────────────────────────────────────────────────────────────
APP_KEY=base64:<clave generada>              # REQUERIDA — ver instrucciones abajo
APP_ENV=local
APP_DEBUG=true
APP_URL=http://localhost:8080
JWT_SECRET=<cadena larga y aleatoria>        # REQUERIDA — mínimo 64 caracteres

# ─── Correo SMTP ──────────────────────────────────────────────────────────────
MAIL_HOST=<servidor smtp>                    # REQUERIDA
MAIL_PORT=465
MAIL_USERNAME=<correo>                       # REQUERIDA
MAIL_PASSWORD=<contraseña smtp>              # REQUERIDA
MAIL_ENCRYPTION=tls

# ─── Puertos (cambiar si hay conflictos locales) ──────────────────────────────
NGINX_PORT=8080
FRONTEND_PORT=4200
```

### Generar APP_KEY

Después del primer `docker compose up -d`, si el contenedor backend está corriendo:

```bash
docker exec ayudando_backend php artisan key:generate --show
```

Copiar el resultado (empieza con `base64:...`) al `.env` como valor de `APP_KEY`, luego:

```bash
docker compose restart backend
```

### Variables requeridas

Las siguientes variables NO tienen valor por defecto — si faltan, el contenedor falla al iniciar:

| Variable            | Por qué es requerida                              |
|---------------------|---------------------------------------------------|
| `POSTGRES_PASSWORD` | PostgreSQL rechaza iniciar sin contraseña         |
| `PGADMIN_PASSWORD`  | pgAdmin no arranca sin credenciales               |
| `APP_KEY`           | Laravel no puede cifrar sesiones ni cookies       |
| `JWT_SECRET`        | La autenticación JWT falla                        |
| `MAIL_HOST`         | El mailer falla si no hay servidor configurado    |
| `MAIL_USERNAME`     | Requerido para autenticarse en SMTP               |
| `MAIL_PASSWORD`     | Requerido para autenticarse en SMTP               |

---

## Environment del frontend

El frontend Angular/Ionic tiene su propia configuración de URLs en:

```
ayudando/frontend/src/environments/environment.ts     ← desarrollo local
ayudando/frontend/src/environments/environment.prod.ts ← producción
```

### Para desarrollo local (Docker)

`environment.ts` debe tener:

```typescript
export const environment = {
  production: false,
  baseUrl: "http://localhost:8080/api/",
  storageUrl: "http://localhost:8080/storage/",
  mapsApiKey: "TU_API_KEY_DE_GOOGLE_MAPS",
};
```

- `baseUrl` apunta a Nginx en el puerto 8080, que proxea las peticiones al backend Laravel
- `storageUrl` también pasa por Nginx para servir archivos del storage de Laravel
- `mapsApiKey` es la clave de Google Maps — solicitarla al equipo

### Para producción

`environment.prod.ts` debe apuntar al dominio real del servidor de producción. No modificar para desarrollo local.

### Después de cambiar el environment

El servidor de desarrollo (`ng serve`) detecta cambios automáticamente y recompila. No es necesario reiniciar el contenedor.

---

## Levantar el entorno

### Primera vez

```bash
docker compose build --no-cache
docker compose up -d
```

### Arranques posteriores (ya construido)

```bash
# Con make:
make up

# Sin make:
docker compose up -d
```

### Detener todo

```bash
# Con make:
make down

# Sin make:
docker compose down
```

> `docker compose down` **no** elimina los volúmenes — los datos de PostgreSQL se conservan.

---

## Importar la base de datos

El dump del proyecto está en `ayudando/ayudando.tar` (formato `pg_restore`, no SQL plano).

### Primera importación

```bash
# Con make:
make db-import

# Sin make:
docker exec -i ayudando_postgres pg_restore -U postgres -d ayudando --no-owner --no-acl < ayudando/ayudando.tar
```

### Verificar que se importó correctamente

Conectarse a la base de datos y listar tablas:

```bash
docker exec -it ayudando_postgres psql -U postgres -d ayudando -c "\dt"
```

Debe mostrar la lista de tablas del proyecto. Si la tabla está vacía o hay error, revisar la sección de Troubleshooting.

### Resetear la base de datos completamente

```bash
docker compose down -v    # elimina TODOS los volúmenes incluyendo datos de postgres
docker compose up -d
make db-import            # o el comando sin make
```

> `down -v` es destructivo — borra todos los datos. Asegurarse de tener el archivo `.tar` antes de ejecutar.

### Conectar pgAdmin a PostgreSQL

1. Abrir `http://localhost:5050`
2. Login con `PGADMIN_EMAIL` y `PGADMIN_PASSWORD` del `.env`
3. Click derecho en **Servers** → **Register** → **Server**
4. Pestaña **General**: poner cualquier nombre (ej: `Ayudando Local`)
5. Pestaña **Connection**:

| Campo    | Valor                                |
|----------|--------------------------------------|
| Host     | `postgres` (nombre del servicio Docker, NO localhost) |
| Port     | `5432`                               |
| Database | valor de `POSTGRES_DB` en el `.env`  |
| Username | valor de `POSTGRES_USER` en el `.env`|
| Password | valor de `POSTGRES_PASSWORD`         |

---

## URLs de acceso

| Servicio         | URL                   | Notas                             |
|------------------|-----------------------|-----------------------------------|
| API Laravel      | http://localhost:8080 | Proxeado por Nginx                |
| Frontend Ionic   | http://localhost:4200 | Dev server de Angular             |
| pgAdmin          | http://localhost:5050 | Credenciales en `.env`            |
| PostgreSQL       | localhost:5432        | Acceso directo a la BD            |

Los puertos pueden cambiarse en `.env` (variables `NGINX_PORT`, `FRONTEND_PORT`, etc.) si hay conflictos con otros servicios locales.

---

## Comandos del día a día

### Con make

```bash
make up              # levantar todos los servicios
make down            # bajar todos los servicios
make restart         # reiniciar todos los servicios
make build           # reconstruir imágenes (sin caché)
make logs            # ver logs en tiempo real
make ps              # estado de los contenedores

make shell-backend   # abrir shell en el contenedor PHP
make shell-frontend  # abrir shell en el contenedor Node
make shell-db        # abrir psql en PostgreSQL

make db-import       # importar dump desde ayudando/ayudando.tar

make migrate         # php artisan migrate
make fresh           # php artisan migrate:fresh --seed
make cache-clear     # limpiar config, cache y rutas de Laravel

make artisan cmd="queue:work"   # cualquier comando artisan
```

### Sin make

```bash
docker compose up -d
docker compose down
docker compose restart
docker compose build --no-cache
docker compose logs -f
docker compose ps

docker exec -it ayudando_backend sh
docker exec -it ayudando_frontend sh
docker exec -it ayudando_postgres psql -U postgres -d ayudando

docker exec -i ayudando_postgres pg_restore -U postgres -d ayudando --no-owner --no-acl < ayudando/ayudando.tar

docker exec ayudando_backend php artisan migrate
docker exec ayudando_backend php artisan migrate:fresh --seed
docker exec ayudando_backend php artisan config:clear && \
  docker exec ayudando_backend php artisan cache:clear && \
  docker exec ayudando_backend php artisan route:clear

docker exec ayudando_backend php artisan <comando>
```

---

## Flujo de arranque automático

### Backend (PHP)

Al iniciar el contenedor, `docker/php/entrypoint.sh` ejecuta automáticamente:

1. `composer install` — si `vendor/` no existe
2. `php artisan storage:link` — si el symlink no existe
3. `chmod -R 775 storage bootstrap/cache`
4. Inicia `php-fpm`

No es necesario correr estos comandos manualmente en el primer arranque.

### Frontend (Node)

Al iniciar el contenedor, `docker/frontend/entrypoint.sh` ejecuta:

1. `npm install --legacy-peer-deps` — si `node_modules/` está vacío
   - Si falla por módulos nativos (como `sharp`), reintenta con `--ignore-scripts`
2. `ng serve --host 0.0.0.0 --port 4200 --disable-host-check --poll 1000`

`node_modules/` vive en un **volumen Docker nombrado** (`frontend_node_modules`), separado de la carpeta del proyecto. Esto evita problemas de rendimiento con bind mounts en Windows/WSL2.

---

## Soporte de archivos grandes

El entorno soporta carga y descarga de archivos hasta 500 MB.

| Parámetro              | Valor  | Archivo                        |
|------------------------|--------|--------------------------------|
| `client_max_body_size` | 500 MB | `docker/nginx/nginx.conf`      |
| `upload_max_filesize`  | 500 MB | `docker/php/php.ini`           |
| `post_max_size`        | 500 MB | `docker/php/php.ini`           |
| `memory_limit`         | 512 MB | `docker/php/php.ini`           |
| `max_execution_time`   | 600 s  | `docker/php/php.ini`           |
| `fastcgi_read_timeout` | 600 s  | `docker/nginx/nginx.conf`      |

Para ajustar estos valores, editar los archivos indicados y reconstruir:

```bash
docker compose build --no-cache backend nginx
docker compose up -d
```

---

## Troubleshooting

### El frontend no carga / muestra 404 en localhost:4200

El servidor de desarrollo tarda en compilar la primera vez. Ver logs:

```bash
docker compose logs frontend -f
```

Esperar `✔ Compiled successfully.` Si hay errores de TypeScript, son del código fuente de la app — verificar que `npm install` completó correctamente.

Si el problema persiste (instalación corrupta de node_modules), reiniciar desde cero:

```bash
docker compose down
docker volume rm docker-li-container_frontend_node_modules
docker compose build --no-cache frontend
docker compose up -d
```

### El backend no conecta a la base de datos

Verificar que postgres está healthy:

```bash
docker compose ps
# ayudando_postgres debe mostrar (healthy)
```

Si no está healthy:

```bash
docker compose logs postgres
```

Causas comunes:
- `POSTGRES_PASSWORD` no definida o vacía en `.env`
- El archivo `.env` no existe (correr `cp .env.example .env`)

### Los cambios en el frontend no se reflejan

El dev server usa polling (`--poll 1000`) para detectar cambios en Windows. Si no funciona:

```bash
docker compose restart frontend
```

### Composer install falla en el contenedor

```bash
docker exec -it ayudando_backend sh
composer install --ignore-platform-reqs -vvv
```

Si hay conflictos con `tymon/jwt-auth` y PHP 8.0, cambiar la imagen base en `docker/php/Dockerfile`:

```dockerfile
# De:
FROM php:8.0-fpm-alpine
# A:
FROM php:7.4-fpm-alpine
```

Luego reconstruir: `docker compose build --no-cache backend && docker compose up -d`

### pgAdmin no puede conectar a PostgreSQL

- El host debe ser `postgres` (nombre del servicio Docker), **no** `localhost`
- El puerto en pgAdmin es `5432` (interno), no el puerto del `.env`
- Verificar que el contenedor de postgres está corriendo: `docker compose ps`

### Puerto ya en uso

Cambiar en `.env`:

```env
NGINX_PORT=8081
FRONTEND_PORT=4201
PGADMIN_PORT=5051
POSTGRES_PORT=5433
```

Luego: `docker compose down && docker compose up -d`

### Variables de entorno no cargadas

Docker Compose lee `.env` automáticamente si está en la misma carpeta que `docker-compose.yml`. Verificar:

```bash
docker compose config    # muestra la configuración con variables resueltas
```

Si las variables aparecen vacías, el `.env` no existe o tiene formato incorrecto.
