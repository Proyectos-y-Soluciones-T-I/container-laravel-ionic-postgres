# Infraestructura Docker Multi-Proyecto

Entorno Docker para múltiples proyectos Laravel 8 + Ionic/Angular 17 + PostgreSQL 14.
Un solo repositorio de infraestructura que sirve a **tres proyectos**: Ayudando, Emergencias y Fiscalización.

> **Regla fundamental**: todo cambio de infraestructura va en `docker/` o en la raíz de este repo.
> El código fuente de cada proyecto vive en `src/<proyecto>/` y **nunca se modifica desde aquí**.

---

## Índice

1. [¿Qué es este repositorio?](#qué-es-este-repositorio)
2. [Estructura del proyecto](#estructura-del-proyecto)
3. [Requisitos previos](#requisitos-previos)
4. [Configuración inicial (primera vez)](#configuración-inicial-primera-vez)
5. [Comandos Docker Compose (forma directa)](#comandos-docker-compose-forma-directa)
6. [Comandos Make (forma corta)](#comandos-make-forma-corta)
7. [Variables de entorno](#variables-de-entorno)
8. [Puertos por proyecto](#puertos-por-proyecto)
9. [Dashboard](#dashboard)
10. [Agregar un nuevo proyecto](#agregar-un-nuevo-proyecto)
11. [Solución de problemas](#solución-de-problemas)
12. [Arquitectura](#arquitectura)

---

## ¿Qué es este repositorio?

Este repositorio contiene **solo la infraestructura Docker** compartida por varios proyectos de Laravel + Ionic/Angular.

| Proyecto | Backend | Frontend | Base de datos |
|----------|---------|----------|---------------|
| **Ayudando** | Laravel 8 | Ionic 7 / Angular 17 | PostgreSQL 14 |
| **Emergencias** | Laravel 8 | Ionic 7 / Angular 17 | PostgreSQL 14 |
| **Fiscalización** | Laravel 8 | Ionic 7 / Angular 17 | PostgreSQL 14 |

Los tres proyectos comparten la misma arquitectura de servicios (PostgreSQL, pgAdmin, Redis, PHP-FPM, Nginx, Node) pero se ejecutan de forma **independiente** usando un patrón de `docker-compose.base.yml` + `docker-compose.<proyecto>.yml`.

Puedes ejecutar uno, dos o los tres proyectos simultáneamente sin conflictos de puertos.

---

## Estructura del proyecto

```
docker-li-container/
├── .env.example                ← Variables de entorno con prefijos por proyecto
├── .env                        ← Creado localmente desde .env.example (NO se commitea)
├── .gitignore
├── Makefile                    ← Comandos rápidos con make
├── README.md                   ← Este archivo
├── docker-compose.base.yml     ← Servicios base compartidos (postgres, pgadmin, redis)
├── docker-compose.ayudando.yml ← Override específico para Ayudando
├── docker-compose.emergencias.yml
├── docker-compose.fiscalizacion.yml
├── docker-compose.gpu.yml      ← Overlay GPU opcional
├── openspec/                   ← Documentación SDD de cambios
├── docker/
│   ├── php/
│   │   ├── Dockerfile          ← PHP 8.1-FPM multi-stage con extensiones Laravel
│   │   ├── entrypoint.sh       ← Arranque automático (composer, cache, queue worker)
│   │   ├── php.ini             ← Configuración PHP (upload 500MB, OPcache, JIT)
│   │   └── zz-docker-user.conf ← Permisos para bind-mount en Windows
│   ├── nginx/
│   │   ├── nginx.conf          ← Configuración global (timeouts 600s, body 500MB)
│   │   └── default.conf        ← Virtual host que proxea a PHP-FPM :9000
│   ├── frontend/
│   │   ├── Dockerfile          ← Node 18.16.1 + Ionic CLI 7 + Angular CLI 17
│   │   └── entrypoint.sh       ← npm install automático + ng serve --poll 1000
│   └── dashboard/
│       └── index.html          ← Panel web con links a todos los proyectos
└── src/                        ← Código fuente de los proyectos (ignorado por git)
    ├── ayudando/
    │   ├── server/             ← Laravel (backend)
    │   ├── frontend/           ← Ionic/Angular (frontend)
    │   └── ayudando.tar        ← Dump de base de datos
    ├── emergencias/
    │   ├── server/
    │   ├── frontend/
    │   └── emergencias.tar
    └── fiscalizacion/
        ├── server/
        ├── frontend/
        └── fiscalizacion.tar
```

---

## Requisitos previos

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) ≥ 4.x (WSL2 habilitado en Windows)
- Git
- `make` (opcional pero recomendado — disponible con Git for Windows, Chocolatey o WSL)
- 8 GB de RAM recomendados (6 GB mínimo)

Verificar instalación:

```bash
docker --version
docker compose version
```

---

## Configuración inicial (primera vez)

### Paso 1 — Clonar este repositorio

```bash
git clone <url-de-este-repo> docker-li-container
cd docker-li-container
```

### Paso 2 — Crear `src/` y clonar los proyectos

```bash
mkdir src

# Clonar cada proyecto dentro de src/
git clone <url-ayudando> src/ayudando
git clone <url-emergencias> src/emergencias
git clone <url-fiscalizacion> src/fiscalizacion
```

Cada proyecto debe tener esta estructura:

```
src/<proyecto>/
├── server/          ← Laravel (backend)
├── frontend/        ← Ionic/Angular (frontend)
└── <proyecto>.tar   ← Dump de la base de datos
```

> Los dumps deben llamarse exactamente como el proyecto (ej: `ayudando.tar`, `emergencias.tar`).

### Paso 3 — Crear el archivo de variables de entorno

```bash
cp .env.example .env
```

Editar `.env` y completar las variables del proyecto que vas a usar. Cada proyecto tiene su propio conjunto de variables con prefijo (`AYUDANDO_`, `EMERGENCIAS_`, `FISCALIZACION_`).

Como mínimo, para el proyecto activo debes completar:

| Variable | Descripción |
|----------|-------------|
| `AYUDANDO_POSTGRES_PASSWORD` | Contraseña de PostgreSQL |
| `AYUDANDO_PGADMIN_PASSWORD` | Contraseña de pgAdmin |
| `AYUDANDO_APP_KEY` | Clave de cifrado de Laravel |
| `AYUDANDO_JWT_SECRET` | Secreto JWT |
| `AYUDANDO_MAIL_HOST` | Servidor SMTP |
| `AYUDANDO_MAIL_USERNAME` | Usuario SMTP |
| `AYUDANDO_MAIL_PASSWORD` | Contraseña SMTP |

> Si vas a trabajar con varios proyectos, completa las variables de todos.

### Paso 4 — Verificar el environment del frontend

Cada proyecto tiene su propia configuración de URLs en:

```
src/<proyecto>/frontend/src/environments/environment.ts
```

Confirmar que las URLs apuntan a `localhost:<puerto-nginx>`:

```typescript
export const environment = {
  production: false,
  baseUrl: "http://localhost:8080/api/",     // Ayudando → 8080
  storageUrl: "http://localhost:8080/storage/",
  mapsApiKey: "TU_API_KEY_DE_GOOGLE_MAPS",
};
```

Puertos correctos por proyecto:
- Ayudando → `http://localhost:8080`
- Emergencias → `http://localhost:8081`
- Fiscalización → `http://localhost:8082`

### Paso 5 — Construir las imágenes y levantar

```bash
# Con make:
make build PROJECT=ayudando
make up PROJECT=ayudando

# Sin make:
docker compose -f docker-compose.base.yml -f docker-compose.ayudando.yml --project-name ayudando build --no-cache
docker compose -f docker-compose.base.yml -f docker-compose.ayudando.yml --project-name ayudando up -d
```

La primera construcción tarda varios minutos porque descarga imágenes base, compila extensiones PHP e instala dependencias.

### Paso 6 — Importar la base de datos

Esperar que PostgreSQL esté healthy:

```bash
docker compose -f docker-compose.base.yml -f docker-compose.ayudando.yml --project-name ayudando ps
# ayudando_postgres debe mostrar (healthy)
```

Luego importar:

```bash
# Con make:
make db-import PROJECT=ayudando

# Sin make:
docker exec -i ayudando_postgres pg_restore -U postgres -d ayudando --no-owner --no-acl < src/ayudando/ayudando.tar
```

> El dump está en formato `.tar` — se importa con `pg_restore`, **no** con `psql`.

### Paso 7 — Verificar que todo esté corriendo

```bash
docker compose -f docker-compose.base.yml -f docker-compose.ayudando.yml --project-name ayudando ps
```

Todos los contenedores deben mostrar `running` o `Up`. El frontend tarda unos minutos adicionales en compilar.

```bash
docker compose -f docker-compose.base.yml -f docker-compose.ayudando.yml --project-name ayudando logs frontend -f
# Esperar: ✔ Compiled successfully.
```

---

## Comandos Docker Compose (forma directa)

Todos los comandos usan el patrón:

```bash
docker compose -f docker-compose.base.yml -f docker-compose.<proyecto>.yml --project-name <proyecto> <comando>
```

### Ayudando

```bash
# Levantar
docker compose -f docker-compose.base.yml -f docker-compose.ayudando.yml --project-name ayudando up -d

# Bajar
docker compose -f docker-compose.base.yml -f docker-compose.ayudando.yml --project-name ayudando down

# Ver logs
docker compose -f docker-compose.base.yml -f docker-compose.ayudando.yml --project-name ayudando logs -f

# Build (sin caché)
docker compose -f docker-compose.base.yml -f docker-compose.ayudando.yml --project-name ayudando build --no-cache

# Estado
docker compose -f docker-compose.base.yml -f docker-compose.ayudando.yml --project-name ayudando ps

# Shell backend
docker exec -it ayudando_backend sh

# Shell frontend
docker exec -it ayudando_frontend sh

# Shell DB
docker exec -it ayudando_postgres psql -U postgres

# Migrate
docker exec ayudando_backend php artisan migrate

# Migrate fresh + seed
docker exec ayudando_backend php artisan migrate:fresh --seed

# Cache clear
docker exec ayudando_backend php artisan config:clear
docker exec ayudando_backend php artisan cache:clear
docker exec ayudando_backend php artisan route:clear

# Artisan (cualquier comando)
docker exec ayudando_backend php artisan <comando>

# Importar DB
docker exec -i ayudando_postgres pg_restore --no-owner --no-acl -U postgres -d ayudando < src/ayudando/ayudando.tar
```

### Emergencias

```bash
# Levantar
docker compose -f docker-compose.base.yml -f docker-compose.emergencias.yml --project-name emergencias up -d

# Shell DB
docker exec -it emergencias_postgres psql -U postgres

# Importar DB
docker exec -i emergencias_postgres pg_restore --no-owner --no-acl -U postgres -d emergencias < src/emergencias/emergencias.tar

# Migrate
docker exec emergencias_backend php artisan migrate

# Cache clear
docker exec emergencias_backend php artisan config:clear
```

### Fiscalización

```bash
# Levantar
docker compose -f docker-compose.base.yml -f docker-compose.fiscalizacion.yml --project-name fiscalizacion up -d

# Shell DB
docker exec -it fiscalizacion_postgres psql -U postgres

# Importar DB
docker exec -i fiscalizacion_postgres pg_restore --no-owner --no-acl -U postgres -d fiscalizacion < src/fiscalizacion/fiscalizacion.tar

# Migrate
docker exec fiscalizacion_backend php artisan migrate
```

> Para los demás comandos (build, logs, artisan, etc.), reemplazar `ayudando` por `emergencias` o `fiscalizacion`.

---

## Comandos Make (forma corta)

```bash
# ─── Gestión del entorno ──────────────────────────────────────────────────────
make up PROJECT=ayudando           # Levantar
make down PROJECT=ayudando         # Bajar
make build PROJECT=ayudando        # Reconstruir imágenes
make logs PROJECT=ayudando         # Logs en tiempo real
make ps PROJECT=ayudando           # Estado de contenedores
make restart PROJECT=ayudando      # Reiniciar servicios

# ─── Shell en contenedores ─────────────────────────────────────────────────────
make shell-backend PROJECT=ayudando   # Shell PHP
make shell-frontend PROJECT=ayudando  # Shell Node
make shell-db PROJECT=ayudando        # psql

# ─── Laravel ───────────────────────────────────────────────────────────────────
make artisan cmd="migrate:status" PROJECT=ayudando  # Cualquier comando artisan
make migrate PROJECT=ayudando                       # php artisan migrate
make fresh PROJECT=ayudando                         # migrate:fresh --seed
make cache-clear PROJECT=ayudando                   # Limpiar config, cache y rutas
make cache-warm PROJECT=ayudando                    # Pre-cachear config y rutas

# ─── Base de datos ────────────────────────────────────────────────────────────
make db-import PROJECT=ayudando     # Importar dump .tar

# ─── GPU (opcional) ────────────────────────────────────────────────────────────
make up-gpu PROJECT=ayudando        # Levantar con GPU
make down-gpu PROJECT=ayudando      # Bajar y limpiar override GPU
make gpu-check PROJECT=ayudando     # Verificar GPU en contenedor

# ─── Diagnóstico ───────────────────────────────────────────────────────────────
make mem-stats                      # Consumo de memoria
make logs-slow PROJECT=ayudando     # Queries lentas de PostgreSQL

# ─── Ayuda ─────────────────────────────────────────────────────────────────────
make help PROJECT=ayudando          # Mostrar todos los comandos
```

---

## Variables de entorno

El archivo `.env` usa un sistema de **prefijos** para aislar las variables de cada proyecto.

### Convención de nombres

```
<PROYECTO>_<VARIABLE>
```

| Prefijo | Proyecto |
|---------|----------|
| `AYUDANDO_` | Ayudando |
| `EMERGENCIAS_` | Emergencias |
| `FISCALIZACION_` | Fiscalización |

### Variables requeridas por proyecto

| Variable | Descripción |
|----------|-------------|
| `<PREFIJO>_POSTGRES_PASSWORD` | Contraseña de PostgreSQL |
| `<PREFIJO>_PGADMIN_PASSWORD` | Contraseña de pgAdmin |
| `<PREFIJO>_APP_KEY` | Clave de cifrado de Laravel (generar con `php artisan key:generate`) |
| `<PREFIJO>_JWT_SECRET` | Secreto para autenticación JWT |
| `<PREFIJO>_MAIL_HOST` | Servidor SMTP |
| `<PREFIJO>_MAIL_USERNAME` | Usuario SMTP |
| `<PREFIJO>_MAIL_PASSWORD` | Contraseña SMTP |

Todas son obligatorias. Si falta alguna, el contenedor falla al iniciar.

### Variables de puerto (con valores por defecto)

| Variable | Default | Descripción |
|----------|---------|-------------|
| `<PREFIJO>_NGINX_PORT` | 8080 / 8081 / 8082 | Puerto de la app (Nginx) |
| `<PREFIJO>_FRONTEND_PORT` | 4200 / 4201 / 4202 | Puerto del frontend (Ionic) |
| `<PREFIJO>_POSTGRES_PORT` | 5432 / 5433 / 5434 | Puerto de PostgreSQL |
| `<PREFIJO>_PGADMIN_PORT` | 5050 / 5051 / 5052 | Puerto de pgAdmin |

Los puertos tienen valores pre-asignados para evitar conflictos entre proyectos. Se pueden sobrescribir en `.env` si hay conflictos con otros servicios locales.

---

## Puertos por proyecto

| Proyecto | App (Nginx) | Frontend (Ionic) | PostgreSQL | pgAdmin |
|----------|-------------|------------------|------------|---------|
| Ayudando | 8080 | 4200 | 5432 | 5050 |
| Emergencias | 8081 | 4201 | 5433 | 5051 |
| Fiscalización | 8082 | 4202 | 5434 | 5052 |

Cada proyecto tiene puertos exclusivos. Puedes ejecutar los tres proyectos simultáneamente sin conflictos.

---

## Dashboard

El archivo `docker/dashboard/index.html` es un panel web que muestra enlaces a todos los proyectos.

### Cómo usarlo

1. Asegúrate de tener al menos un proyecto corriendo
2. Abre el archivo directamente en tu navegador (doble click)
3. Verás tarjetas para cada proyecto con enlaces a:
   - 🌐 App (Nginx) — la aplicación Laravel
   - ⚛ Frontend (Ionic) — el dev server de Angular
   - 🗄 pgAdmin — administrador de base de datos
   - 🐘 PostgreSQL — puerto de conexión directa

El dashboard es un archivo HTML estático, no requiere servidor. Se puede abrir desde el sistema de archivos.

---

## Agregar un nuevo proyecto

Para agregar un cuarto proyecto (ej: `nuevoproyecto`), seguir estos pasos:

### 1. Asignar puertos

Elegir 4 puertos libres que no conflictúen con los existentes:

| Servicio | Puerto sugerido |
|----------|-----------------|
| Nginx | 8083 |
| Frontend | 4203 |
| PostgreSQL | 5435 |
| pgAdmin | 5053 |

### 2. Crear `docker-compose.nuevoproyecto.yml`

Copiar `docker-compose.ayudando.yml` y reemplazar:

- Nombre del proyecto en comentarios y `APP_NAME`
- Prefijo de variables: `AYUDANDO_` → `NUEVOPROYECTO_`
- Puertos: 8080 → 8083, 4200 → 4203, 5432 → 5435, 5050 → 5053
- Nombre de la red: `ayudando_net` → `nuevoproyecto_net`
- Nombre de volúmenes frontend (opcional, para aislar node_modules)
- Database: `ayudando` → `nuevoproyecto`

### 3. Agregar variables al `.env.example`

```env
# ============================================================
# NUEVOPROYECTO
# ============================================================
NUEVOPROYECTO_POSTGRES_PASSWORD=change_me
NUEVOPROYECTO_PGADMIN_PASSWORD=change_me
NUEVOPROYECTO_APP_KEY=base64:GENERATE_WITH_php_artisan_key_generate
NUEVOPROYECTO_JWT_SECRET=GENERATE_A_STRONG_SECRET
NUEVOPROYECTO_MAIL_HOST=your.smtp.host
NUEVOPROYECTO_MAIL_USERNAME=your@email.com
NUEVOPROYECTO_MAIL_PASSWORD=change_me

NUEVOPROYECTO_NGINX_PORT=8083
NUEVOPROYECTO_FRONTEND_PORT=4203
NUEVOPROYECTO_POSTGRES_PORT=5435
NUEVOPROYECTO_PGADMIN_PORT=5053
```

### 4. Agregar al Makefile

```makefile
VALID_PROJECTS := ayudando emergencias fiscalizacion nuevoproyecto
```

### 5. Agregar al dashboard

Editar `docker/dashboard/index.html` y agregar una nueva tarjeta siguiendo el mismo patrón de las existentes.

### 6. Verificar que funciona

```bash
make build PROJECT=nuevoproyecto
make up PROJECT=nuevoproyecto
make ps PROJECT=nuevoproyecto
```

---

## Solución de problemas

### Backend no conecta a la base de datos

Verificar que PostgreSQL está healthy:

```bash
docker compose -f docker-compose.base.yml -f docker-compose.ayudando.yml --project-name ayudando ps
# ayudando_postgres debe mostrar (healthy)
```

Si no está healthy, revisar logs:

```bash
docker compose -f docker-compose.base.yml -f docker-compose.ayudando.yml --project-name ayudando logs postgres
```

Causas comunes:
- `POSTGRES_PASSWORD` no definida en `.env` (revisar que la variable con el prefijo correcto esté completa)
- El archivo `.env` no existe (correr `cp .env.example .env`)
- El proyecto activo no coincide: `PROJECT=ayudando` en `.env` pero se ejecutó con `PROJECT=emergencias`

### Composer install falla en el contenedor

```bash
docker exec -it ayudando_backend sh
composer install --ignore-platform-reqs -vvv
```

Si hay conflictos con `tymon/jwt-auth` y PHP 8.1, verificar que la versión de `tymon/jwt-auth` soporta PHP 8.1 (requerir `^2.0`).

### pgAdmin no puede conectar a PostgreSQL

- El host debe ser `postgres` (nombre del servicio Docker), **no** `localhost`
- El puerto en pgAdmin es `5432` (interno del contenedor), **no** el puerto host del `.env`
- Verificar que el contenedor de postgres está corriendo
- Verificar que la contraseña en pgAdmin coincide con `<PREFIJO>_POSTGRES_PASSWORD` del `.env`

### Puerto ya en uso

Si el puerto 8080 está ocupado por otro servicio local, sobrescribir en `.env`:

```env
AYUDANDO_NGINX_PORT=8083
```

Luego:

```bash
docker compose -f docker-compose.base.yml -f docker-compose.ayudando.yml --project-name ayudando down
docker compose -f docker-compose.base.yml -f docker-compose.ayudando.yml --project-name ayudando up -d
```

### Cambios de frontend no se reflejan

El dev server usa polling (`--poll 1000`) para detectar cambios en Windows. Si no funciona:

```bash
docker compose -f docker-compose.base.yml -f docker-compose.ayudando.yml --project-name ayudando restart frontend
```

### Reset completo de la base de datos

```bash
# ⚠️ Destructivo — elimina todos los datos
docker compose -f docker-compose.base.yml -f docker-compose.ayudando.yml --project-name ayudando down -v
docker compose -f docker-compose.base.yml -f docker-compose.ayudando.yml --project-name ayudando up -d
make db-import PROJECT=ayudando
```

> `down -v` elimina los volúmenes. Asegurarse de tener el archivo `.tar` antes de ejecutar.

### Variables de entorno no cargadas

Docker Compose lee `.env` automáticamente si está en la raíz del proyecto. Verificar:

```bash
docker compose -f docker-compose.base.yml -f docker-compose.ayudando.yml --project-name ayudando config
```

Si las variables aparecen vacías, el `.env` no existe, tiene formato incorrecto, o el prefijo no coincide.

### Contenedor supera el límite de memoria

```bash
docker stats --no-stream
```

Si un contenedor está cerca del 100%, aumentar el límite en `docker-compose.base.yml` o en el override del proyecto, y aplicar con `up -d`.

---

## Arquitectura

### Patrón base + override

La arquitectura usa el patrón **base + override** de Docker Compose:

- **`docker-compose.base.yml`**: Define los servicios compartidos (PostgreSQL, pgAdmin, Redis) con configuración genérica. No expone puertos al host ni define credenciales — eso lo hace cada override.

- **`docker-compose.<proyecto>.yml`**: Override específico por proyecto. Añade los servicios backend (PHP-FPM), Nginx y frontend (Node), y configura los puertos y credenciales específicos del proyecto usando variables con prefijo.

```bash
# Composición final:
docker compose -f docker-compose.base.yml -f docker-compose.ayudando.yml --project-name ayudando up -d
```

Docker Compose fusiona ambos archivos: los servicios del override se agregan, y si un servicio existe en ambos archivos, las configuraciones se fusionan (environment, volumes, ports se combinan; las llaves duplicadas en environment ganan con el override).

### Por qué Nginx no necesita cambios por proyecto

El archivo `docker/nginx/default.conf` usa la ruta genérica `/var/www/html` y proxea a `backend:9000`. Como cada proyecto tiene su propio stack aislado con su propia red, el mismo archivo de configuración de Nginx funciona para todos los proyectos sin modificaciones.

### Aislamiento de volúmenes

| Volumen | Propósito | Aislamiento |
|---------|-----------|-------------|
| `postgres_data` | Datos persistentes de PostgreSQL | Compartido (un volumen único) |
| `pgadmin_data` | Configuración de pgAdmin | Compartido |
| `frontend_node_modules` | Dependencias npm del frontend | Por proyecto (nombre único) |
| `frontend_angular_cache` | Caché de compilación Angular | Por proyecto |

Los volúmenes `frontend_node_modules` y `frontend_angular_cache` se crean con nombres exclusivos por proyecto (prefijados por `--project-name`). Esto aísla las dependencias npm y evita conflictos de versión entre proyectos.

### Flujo de datos

```
Navegador → Nginx :8080 → PHP-FPM (backend) :9000
                                     ↓
                          PostgreSQL :5432
                          Redis :6379
```

```
Navegador → Frontend (ng serve) :4200 → API via Nginx :8080/api/*
```

### Comunicación entre servicios

Todos los servicios se comunican por el nombre del servicio Docker (ej: `postgres`, `redis`, `backend`), no por `localhost`. Esto funciona porque todos comparten la misma red interna (`<proyecto>_net`).

### Archivos de entrada compartidos

Los archivos `php.ini`, `nginx.conf`, `default.conf` y las plantillas de entrypoint viven en `docker/` y son compartidos por todos los proyectos. No necesitan cambios por proyecto porque:

- Las rutas dentro del contenedor son las mismas para todos los proyectos (`/var/www/html`)
- Los nombres de servicios son los mismos (`postgres`, `backend`, etc.)
- La red interna resuelve los nombres de servicio independientemente del proyecto
