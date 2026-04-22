# Ayudando — Docker Environment

Repositorio independiente que contiene **únicamente** la infraestructura Docker del proyecto Ayudando.  
El código fuente del proyecto (`ayudando/`) se clona localmente y **nunca se modifica desde aquí**.

---

## Arquitectura

```
docker-li-container/          ← este repo
├── docker-compose.yml
├── .env                      ← credenciales locales (NO commitear)
├── .env.example              ← plantilla sin credenciales (SÍ en git)
├── Makefile                  ← comandos rápidos
├── docker/
│   ├── php/                  ← PHP 8.0-FPM + extensiones
│   ├── nginx/                ← reverse proxy + large file support
│   └── frontend/             ← Node 18.16.1 + Ionic 7 + Angular 17
└── ayudando/                 ← proyecto fuente (ignorado por git)
    ├── server/               ← Laravel 8 (backend)
    └── frontend/             ← Ionic/Angular 17 (frontend)
```

### Servicios

| Contenedor          | Imagen                    | Puerto local | Descripción                    |
|---------------------|---------------------------|--------------|--------------------------------|
| `ayudando_postgres` | postgres:**14.22**-alpine | 5432         | Base de datos PostgreSQL       |
| `ayudando_pgadmin`  | dpage/pgadmin4:**7.3**    | 5050         | Administrador de base de datos |
| `ayudando_backend`  | (build local) PHP 8.0     | —            | Laravel 8 via PHP-FPM          |
| `ayudando_nginx`    | nginx:1.25-alpine         | **8080**     | Reverse proxy + API            |
| `ayudando_frontend` | (build local) Node 18     | **4200**     | Ionic/Angular dev server       |

### Red interna

Todos los servicios comparten la red `ayudando_net`. Nginx se comunica con `backend:9000` (FastCGI). La base de datos es accesible internamente como `postgres:5432`.

---

## Stack de versiones

| Tecnología     | Versión              |
|----------------|----------------------|
| PHP            | 8.0-fpm-alpine       |
| Laravel        | 8.x                  |
| Node.js        | **18.16.1**          |
| Ionic CLI      | 7                    |
| Angular CLI    | 17                   |
| PostgreSQL     | **14.22**-alpine     |
| pgAdmin        | **7.3**              |
| Nginx          | 1.25-alpine          |
| Composer       | 2.5.8                |

---

## Requisitos previos

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) ≥ 4.x (con WSL2 en Windows)
- Git
- (Opcional) `make` — disponible con Git for Windows o Chocolatey

Verificar instalación:
```bash
docker --version
docker compose version
```

---

## Configuración inicial

### 1. Clonar este repositorio

```bash
git clone <url-de-este-repo> docker-li-container
cd docker-li-container
```

### 2. Colocar el proyecto Ayudando

El proyecto fuente debe estar en `ayudando/` (ignorado por git):

```bash
# Opción A: clonar el proyecto dentro de esta carpeta
git clone <url-de-ayudando> ayudando

# Opción B: copiar manualmente la carpeta ayudando/ aquí
```

Estructura esperada:
```
docker-li-container/
└── ayudando/
    ├── server/          ← Laravel (backend)
    ├── frontend/        ← Ionic (frontend)
    └── ayudando.sql     ← dump inicial de la base de datos
```

### 3. Configurar variables de entorno

```bash
cp .env.example .env
```

Editar `.env` con las credenciales reales del proyecto.

> **NUNCA commitear `.env`** — contiene credenciales. Está en `.gitignore`.

Estructura del `.env` (ver `.env.example` para referencia):

```env
# Base de datos
POSTGRES_DB=nombre_base_datos
POSTGRES_USER=usuario_db
POSTGRES_PASSWORD=contraseña_segura

# pgAdmin
PGADMIN_EMAIL=admin@dominio.local
PGADMIN_PASSWORD=contraseña_pgadmin

# Laravel — generar con: docker exec ayudando_backend php artisan key:generate
APP_KEY=base64:...
APP_URL=http://localhost:8080
JWT_SECRET=clave_jwt_larga_y_aleatoria

# Mail SMTP
MAIL_HOST=servidor.smtp.com
MAIL_PORT=465
MAIL_USERNAME=correo@dominio.com
MAIL_PASSWORD=contraseña_smtp
MAIL_ENCRYPTION=tls

# Puertos expuestos
NGINX_PORT=8080
FRONTEND_PORT=4200
PGADMIN_PORT=5050
POSTGRES_PORT=5432
```

---

## Levantar el entorno

### Primera vez (construye las imágenes)

```bash
docker compose up -d --build
```

Esto toma varios minutos la primera vez:
- Descarga imágenes base de Docker Hub
- Instala extensiones PHP (pdo_pgsql, gd, zip, bcmath, intl, exif, opcache)
- Instala Composer 2.5.8
- Instala Ionic CLI 7 y Angular CLI 17

### Importar la base de datos

Después de que el contenedor de postgres esté `healthy`:

```bash
make db-import
# equivalente a:
# docker exec -i ayudando_postgres psql -U $POSTGRES_USER -d $POSTGRES_DB < ayudando/ayudando.sql
```

### Arranques posteriores

```bash
make up
# equivalente a: docker compose up -d
```

---

## URLs de acceso

| Servicio              | URL                     | Credenciales             |
|-----------------------|-------------------------|--------------------------|
| **API (Laravel)**     | http://localhost:8080   | —                        |
| **Frontend (Ionic)**  | http://localhost:4200   | —                        |
| **pgAdmin**           | http://localhost:5050   | definidas en `.env`      |
| **PostgreSQL**        | localhost:5432          | definidas en `.env`      |

> Los puertos pueden cambiarse en `.env` si hay conflictos con otros servicios locales.

---

## pgAdmin — Conectar al servidor PostgreSQL

1. Abrir http://localhost:5050
2. Login con `PGADMIN_EMAIL` y `PGADMIN_PASSWORD` del `.env`
3. Click derecho en **Servers** → **Register** → **Server**
4. Pestaña **General**: nombre `Ayudando`
5. Pestaña **Connection**:

| Campo    | Valor                          |
|----------|--------------------------------|
| Host     | `postgres`                     |
| Port     | `5432`                         |
| Database | valor de `POSTGRES_DB`         |
| Username | valor de `POSTGRES_USER`       |
| Password | valor de `POSTGRES_PASSWORD`   |

> **IMPORTANTE:** el host es `postgres` (nombre del servicio Docker), NO `localhost`.

---

## Comandos Makefile

```bash
make up              # levantar todos los servicios en background
make down            # bajar todos los servicios
make restart         # reiniciar todos los servicios
make build           # reconstruir imágenes sin caché
make logs            # ver logs en tiempo real (todos los servicios)
make ps              # estado de los contenedores

make shell-backend   # abrir shell en el contenedor PHP
make shell-frontend  # abrir shell en el contenedor Node
make shell-db        # abrir psql en PostgreSQL

make db-import       # importar ayudando/ayudando.sql a la base de datos

make migrate         # php artisan migrate
make fresh           # php artisan migrate:fresh --seed
make cache-clear     # limpiar config, cache y rutas de Laravel

make artisan cmd="<comando>"   # cualquier comando artisan
# Ejemplo: make artisan cmd="queue:work"
```

Comandos Docker directos equivalentes:

```bash
docker compose up -d --build
docker compose down
docker compose logs -f backend
docker exec -it ayudando_backend sh
docker exec ayudando_backend php artisan migrate
```

---

## Soporte de archivos grandes

Configuración optimizada para cargar y descargar archivos grandes (dumps de base de datos, documentos, imágenes):

| Parámetro                | Valor   | Archivo                      |
|--------------------------|---------|------------------------------|
| `client_max_body_size`   | 500 MB  | docker/nginx/nginx.conf      |
| `upload_max_filesize`    | 500 MB  | docker/php/php.ini           |
| `post_max_size`          | 500 MB  | docker/php/php.ini           |
| `memory_limit`           | 512 MB  | docker/php/php.ini           |
| `max_execution_time`     | 600 s   | docker/php/php.ini           |
| `fastcgi_read_timeout`   | 600 s   | docker/nginx/nginx.conf      |
| `proxy_read_timeout`     | 600 s   | docker/nginx/nginx.conf      |

Para ajustar, editar los archivos indicados y luego:

```bash
make build && make up
```

---

## Envío de correos

Laravel usa SMTP externo. La configuración se toma del `.env` — no hay credenciales hardcodeadas en el código ni en los archivos del repositorio.

Variables requeridas:

```env
MAIL_MAILER=smtp
MAIL_HOST=tu.servidor.smtp
MAIL_PORT=465
MAIL_ENCRYPTION=tls
MAIL_USERNAME=correo@tudominio.com
MAIL_PASSWORD=tu_contraseña_smtp
```

El contenedor `backend` necesita salida a internet en el puerto definido en `MAIL_PORT`. Docker Desktop lo permite por defecto.

Para probar desde el contenedor:

```bash
make artisan cmd="tinker"
# Dentro de tinker:
# Mail::raw('test', fn($m) => $m->to('tu@email.com')->subject('Test'));
```

---

## Comportamiento del primer arranque

### Backend (PHP)

El entrypoint (`docker/php/entrypoint.sh`) ejecuta automáticamente:

1. `composer install` si `vendor/` no existe
2. `php artisan storage:link` si el symlink no existe
3. `chmod -R 775 storage bootstrap/cache`
4. Inicia `php-fpm`

> El directorio `vendor/` se crea dentro de `ayudando/server/` — es código generado, no fuente del proyecto.

### Frontend (Node)

El entrypoint (`docker/frontend/entrypoint.sh`) ejecuta automáticamente:

1. `npm install --legacy-peer-deps` si `node_modules/` está vacío
2. `ng serve --host 0.0.0.0 --port 4200 --disable-host-check --poll 1000`

`node_modules/` vive en un **volumen Docker nombrado** (`frontend_node_modules`) — no en la carpeta del proyecto — para evitar problemas de rendimiento con bind mounts en Windows.

---

## Volúmenes Docker

| Volumen                  | Contenido                              |
|--------------------------|----------------------------------------|
| `postgres_data`          | datos de PostgreSQL (persistente)      |
| `pgadmin_data`           | configuración de pgAdmin (persistente) |
| `frontend_node_modules`  | node_modules del frontend              |

Para resetear la base de datos completamente:

```bash
docker compose down -v   # elimina TODOS los volúmenes
make up
make db-import
```

> ⚠️ `down -v` elimina todos los datos de postgres. Asegurarse de tener el SQL dump antes de ejecutar.

---

## Troubleshooting

### El backend no conecta a la base de datos

```bash
make logs
# buscar: ayudando_backend | SQLSTATE[08006]
```

Verificar que postgres está healthy:
```bash
docker compose ps
# ayudando_postgres debe mostrar (healthy)
```

Si no está healthy:
```bash
docker compose logs postgres
```

Causas comunes: `POSTGRES_PASSWORD` no definida en `.env`, o el archivo `.env` no existe.

### Variables de entorno no cargadas

Docker Compose lee `.env` automáticamente si está en la misma carpeta que `docker-compose.yml`. Verificar:

```bash
# Debe existir y tener contenido
cat .env

# Ver qué variables resolvió docker-compose
docker compose config
```

### Cambios en el frontend no se reflejan

El dev server usa polling (`--poll 1000`) para detectar cambios en Windows. Si aún no funciona:

```bash
docker compose restart frontend
```

### Composer install falla dentro del contenedor

```bash
make shell-backend
composer install --ignore-platform-reqs -vvv
```

Si hay conflictos con `tymon/jwt-auth dev-develop` en PHP 8.0, cambiar la imagen base en `docker/php/Dockerfile`:

```dockerfile
# Cambiar:
FROM php:8.0-fpm-alpine
# Por:
FROM php:7.4-fpm-alpine
```

Luego: `make build && make up`

### pgAdmin no puede conectar a postgres

- El host debe ser `postgres` (nombre del servicio), NO `localhost`
- El puerto en pgAdmin es `5432` (interno), no el puerto expuesto en el host
- Verificar que postgres esté corriendo: `docker compose ps`

### Puerto ya en uso

Cambiar los puertos en `.env`:

```env
NGINX_PORT=8081
FRONTEND_PORT=4201
PGADMIN_PORT=5051
```

---

## Variables de entorno — referencia completa

| Variable            | Default         | Requerida | Descripción                        |
|---------------------|-----------------|-----------|------------------------------------|
| `POSTGRES_DB`       | `ayudando`      | No        | Nombre de la base de datos         |
| `POSTGRES_USER`     | `postgres`      | No        | Usuario de postgres                |
| `POSTGRES_PASSWORD` | —               | **Sí**    | Contraseña de postgres             |
| `POSTGRES_PORT`     | `5432`          | No        | Puerto expuesto de postgres        |
| `PGADMIN_EMAIL`     | `admin@ayudando.local` | No | Email de login en pgAdmin         |
| `PGADMIN_PASSWORD`  | —               | **Sí**    | Contraseña de pgAdmin              |
| `PGADMIN_PORT`      | `5050`          | No        | Puerto expuesto de pgAdmin         |
| `APP_KEY`           | —               | **Sí**    | Laravel APP_KEY (generar con artisan) |
| `APP_ENV`           | `local`         | No        | Entorno Laravel                    |
| `APP_DEBUG`         | `true`          | No        | Debug mode Laravel                 |
| `APP_URL`           | `http://localhost:8080` | No | URL base de la API              |
| `JWT_SECRET`        | —               | **Sí**    | Clave JWT (larga, aleatoria)       |
| `MAIL_HOST`         | —               | **Sí**    | Servidor SMTP                      |
| `MAIL_PORT`         | `465`           | No        | Puerto SMTP                        |
| `MAIL_USERNAME`     | —               | **Sí**    | Usuario SMTP                       |
| `MAIL_PASSWORD`     | —               | **Sí**    | Contraseña SMTP                    |
| `MAIL_ENCRYPTION`   | `tls`           | No        | Cifrado SMTP                       |
| `NGINX_PORT`        | `8080`          | No        | Puerto expuesto del API            |
| `FRONTEND_PORT`     | `4200`          | No        | Puerto del dev server Angular      |

> Las variables marcadas **Sí** en la columna *Requerida* deben estar presentes en `.env` o el contenedor fallará al iniciar.

---

## Estructura de archivos del repo

```
docker-li-container/
│
├── docker-compose.yml           # Definición de los 5 servicios
├── .env                         # Variables locales (NO en git)
├── .env.example                 # Plantilla sin credenciales (SÍ en git)
├── .gitignore                   # Excluye ayudando/, .env, etc.
├── Makefile                     # Comandos de gestión
│
├── docker/
│   ├── php/
│   │   ├── Dockerfile           # PHP 8.0-fpm-alpine + extensiones
│   │   ├── entrypoint.sh        # composer install + artisan setup
│   │   └── php.ini              # 500MB upload, 512MB RAM, 600s timeout
│   │
│   ├── nginx/
│   │   ├── nginx.conf           # Config global (large file, timeouts)
│   │   └── default.conf         # Server block + FastCGI + /storage alias
│   │
│   └── frontend/
│       ├── Dockerfile           # node:18.16.1 + Ionic 7 + Angular 17
│       └── entrypoint.sh        # npm install + ng serve
│
└── ayudando/                    # ← NO en git (ver .gitignore)
    ├── server/                  # Laravel 8 — código fuente backend
    ├── frontend/                # Ionic/Angular 17 — código fuente frontend
    └── ayudando.sql             # Dump inicial de la base de datos
```

---

## Separación de repositorios

Este repo (`docker-li-container`) es **independiente** del proyecto `ayudando`.

```
repos/
├── docker-li-container/    ← este repo (infraestructura Docker)
│   └── ayudando/           ← carpeta ignorada por git, clonada localmente
└── ayudando/               ← repo original del proyecto (no se modifica)
```

Flujo recomendado para un nuevo desarrollador:

```bash
# 1. Clonar infra
git clone <url-docker-li-container> docker-li-container
cd docker-li-container

# 2. Clonar el proyecto dentro
git clone <url-ayudando> ayudando

# 3. Configurar variables (pedir credenciales al equipo)
cp .env.example .env
# editar .env con las credenciales reales

# 4. Levantar
docker compose up -d --build

# 5. Importar base de datos
make db-import
```
