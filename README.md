# Infraestructura Docker Multi-Proyecto

Entorno Docker para **Ayudando**, **Emergencias** y **Fiscalización** — proyectos Laravel 8 + Ionic/Angular 17 + PostgreSQL 14.

Un solo repositorio de infraestructura. El código fuente de cada proyecto vive en `src/<proyecto>/` y **nunca se modifica desde aquí**.

---

## Índice

1. [¿Qué es este repositorio?](#qué-es-este-repositorio)
2. [Arquitectura](#arquitectura)
3. [Estructura de archivos](#estructura-de-archivos)
4. [Requisitos previos](#requisitos-previos)
5. [Configuración inicial](#configuración-inicial)
6. [Comandos Docker](#comandos-docker)
   - [Build de producción (Ionic)](#build-de-producción-ionic)
7. [@ngx-formly — instalación opcional](#ngx-formly--instalación-opcional)
8. [Dashboard](#dashboard)
9. [Make — atajos opcionales](#make--atajos-opcionales)
10. [Variables de entorno](#variables-de-entorno)
11. [Puertos](#puertos)
12. [Agregar un nuevo proyecto](#agregar-un-nuevo-proyecto)
13. [Solución de problemas](#solución-de-problemas)

---

## ¿Qué es este repositorio?

Infraestructura Docker compartida para múltiples proyectos. Cada proyecto es independiente y usa los mismos servicios base: PHP-FPM, Nginx, Node, Redis. La base de datos y pgAdmin son **compartidos** entre todos.

| Proyecto | Backend | Frontend | Puerto API | Puerto UI |
|---|---|---|---|---|
| **Ayudando** | Laravel 8 | Ionic / Angular 17 | 8080 | 4200 |
| **Emergencias** | Laravel 8 | Ionic / Angular 17 | 8081 | 4201 |
| **Fiscalización** | Laravel 8 | Ionic / Angular 17 | 8082 | 4202 |

> Solo se usa **un proyecto a la vez**. La infraestructura compartida (postgres, pgAdmin, dashboard) corre siempre.

---

## Arquitectura

```
┌─────────────────────────────────────────────────────┐
│  docker-compose.shared.yml  (siempre activo)        │
│                                                     │
│  shared_postgres :5432   shared_pgadmin :5050       │
│  shared_dashboard :8090                             │
└─────────────────────────────────────────────────────┘
           ↑ shared_net (red Docker interna)
┌─────────────────────────────────────────────────────┐
│  docker-compose.<proyecto>.yml  (uno a la vez)      │
│                                                     │
│  <proyecto>_nginx    <proyecto>_backend             │
│  <proyecto>_frontend <proyecto>_redis               │
└─────────────────────────────────────────────────────┘
```

**Dos capas:**

- **Shared** (`docker-compose.shared.yml`): PostgreSQL, pgAdmin y el Dashboard. Se levanta una sola vez y nunca se baja salvo que quieras resetear la DB.
- **Por proyecto** (`docker-compose.<proyecto>.yml`): backend PHP, Nginx, frontend Node y Redis. Se levanta/baja según en qué proyecto se está trabajando.

Los proyectos se conectan a la base de datos compartida a través de la red `shared_net`.

---

## Estructura de archivos

```
container-laravel-ionic-postgres/
├── .env.example                      ← Variables de infraestructura compartida
├── .env                              ← Creado localmente desde .env.example (no commitear)
├── envs/
│   ├── ayudando.env.example          ← Template de secretos del proyecto Ayudando
│   ├── emergencias.env.example       ← Template de secretos del proyecto Emergencias
│   ├── fiscalizacion.env.example     ← Template de secretos del proyecto Fiscalización
│   └── *.env                         ← Creados localmente (ignorados por git)
├── .gitattributes                    ← Normalización LF para todo el repo
├── Makefile                          ← Atajos opcionales (ver sección Make)
├── CHANGELOG.md                      ← Historial de cambios del proyecto
├── MOBILE_BUILD.md                   ← Guía de build y firma para Android/iOS
│
├── docker-compose.shared.yml         ← Infraestructura compartida (postgres, pgadmin, dashboard)
├── docker-compose.ayudando.yml       ← Servicios del proyecto Ayudando
├── docker-compose.emergencias.yml    ← Servicios del proyecto Emergencias
├── docker-compose.fiscalizacion.yml  ← Servicios del proyecto Fiscalización
├── docker-compose.gpu.yml            ← Overlay GPU opcional
│
├── scripts/
│   └── setup.sh                      ← Setup interactivo (pregunta si instalar @ngx-formly)
│
├── docker/
│   ├── php/
│   │   ├── Dockerfile                ← PHP 8.1-FPM con extensiones Laravel
│   │   ├── entrypoint.sh             ← Arranca composer, artisan y queue worker
│   │   ├── php.ini                   ← Upload 500MB, OPcache, JIT
│   │   └── zz-docker-user.conf       ← Permisos para bind-mount en Windows
│   ├── nginx/
│   │   ├── nginx.conf                ← Timeouts 600s, body 500MB
│   │   └── default.conf              ← Proxy a PHP-FPM :9000
│   ├── frontend/
│   │   ├── Dockerfile                ← Node 18 + Ionic CLI 7 + Angular CLI 17 + unzip
│   │   └── entrypoint.sh             ← npm install + extracción @ngx-formly + ng serve
│   └── dashboard/
│       ├── index.html                ← Dashboard con health checks en tiempo real
│       ├── nginx.conf.template       ← Config nginx del dashboard (se procesa al inicio)
│       └── entrypoint.sh             ← Resuelve IP del host e inicia nginx
│
└── src/                              ← Código fuente (ignorado por git)
    ├── ayudando/
    │   ├── server/                   ← Laravel (backend)
    │   ├── frontend/                 ← Ionic/Angular
    │   └── ayudando.tar              ← Dump de base de datos
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
- 8 GB RAM recomendados (6 GB mínimo)

Verificar:

```bash
docker --version
docker compose version
```

### Dependencias de desarrollo (git hooks)

Este repositorio usa **Husky + commitlint** para validar mensajes de commit
([Conventional Commits](https://www.conventionalcommits.org/)). Requiere Node
instalado en el host — solo para los hooks, no para correr los contenedores.

Instalá con el package manager que uses:

```bash
# npm
npm install

# pnpm
pnpm install

# bun
bun install
```

Los hooks quedan activos automáticamente via el script `prepare`.
Si no tenés Node, los hooks no bloquean el trabajo — solo no se validan los mensajes localmente.

---

## Configuración inicial

### 1. Clonar el repo

```bash
git clone <url-de-este-repo>
cd container-laravel-ionic-postgres
```

### 2. Clonar los proyectos en `src/`

```bash
mkdir src
git clone <url-ayudando>      src/ayudando
git clone <url-emergencias>   src/emergencias
git clone <url-fiscalizacion> src/fiscalizacion
```

Cada proyecto debe tener esta estructura:

```
src/<proyecto>/
├── server/        ← Laravel (backend)
├── frontend/      ← Ionic/Angular (frontend)
└── <proyecto>.tar ← Dump de base de datos (formato pg_restore)
```

### 3. Crear los archivos `.env`

```bash
# Infraestructura compartida
cp .env.example .env

# Secretos por proyecto (copiar solo los que vas a usar)
cp envs/ayudando.env.example      envs/ayudando.env
cp envs/emergencias.env.example   envs/emergencias.env
cp envs/fiscalizacion.env.example envs/fiscalizacion.env
```

Editar cada archivo y completar los valores marcados con `change_me`:

| Archivo | Variables requeridas |
|---|---|
| `.env` | `POSTGRES_PASSWORD`, `PGADMIN_PASSWORD` |
| `envs/<proyecto>.env` | `APP_KEY` (paso 6), `JWT_SECRET`, `MAIL_HOST/USERNAME/PASSWORD` |

> Tip: usá el **Generador de .env** en http://localhost:8090 para generar los contenidos con un formulario visual.

### 4. Levantar la infraestructura compartida

```bash
docker compose -f docker-compose.shared.yml up -d
```

Verificar que postgres esté healthy **antes de continuar**:

```bash
docker compose -f docker-compose.shared.yml ps
# shared_postgres debe mostrar (healthy)
```

### 5. Levantar el proyecto

**Opción A — Setup automático (recomendado para primera vez):**

```bash
bash scripts/setup.sh ayudando
# Crea envs/ayudando.env desde el template si no existe y levanta el proyecto
```

Equivalente con Make:

```bash
make setup PROJECT=ayudando
```

**Opción B — Docker directo:**

```bash
docker compose -f docker-compose.ayudando.yml --project-name ayudando up -d
```

La primera vez tarda varios minutos — descarga imágenes, compila extensiones PHP e instala dependencias npm.

### 6. Generar APP_KEY

```bash
docker exec ayudando_backend php artisan key:generate
```

Copiar el valor generado (`base64:...`) y pegarlo en `envs/ayudando.env` como `APP_KEY`.

### 7. Importar la base de datos

```bash
docker exec -i shared_postgres pg_restore -U postgres -d ayudando --no-owner --no-acl < src/ayudando/ayudando.tar
```

> El dump está en formato `.tar` — se importa con `pg_restore`, **no** con `psql`.

### 8. Verificar

```bash
docker compose -f docker-compose.ayudando.yml --project-name ayudando ps
```

Para seguir el progreso del frontend:

```bash
docker compose -f docker-compose.ayudando.yml --project-name ayudando logs -f frontend
# Esperar: ✔ Compiled successfully.
```

---

## Comandos Docker

### Infraestructura compartida

```bash
# Levantar postgres + pgAdmin + dashboard (una sola vez)
docker compose -f docker-compose.shared.yml up -d

# Ver estado
docker compose -f docker-compose.shared.yml ps

# Ver logs
docker compose -f docker-compose.shared.yml logs -f

# Bajar (solo para resetear — pierde datos si usás down -v)
docker compose -f docker-compose.shared.yml down
```

### Ciclo de vida del proyecto

> Reemplazá `ayudando` / `docker-compose.ayudando.yml` por el proyecto que corresponda.

```bash
# Levantar
docker compose -f docker-compose.ayudando.yml --project-name ayudando up -d

# Bajar
docker compose -f docker-compose.ayudando.yml --project-name ayudando down

# Reconstruir imágenes (sin caché)
docker compose -f docker-compose.ayudando.yml --project-name ayudando build --no-cache

# Ver estado
docker compose -f docker-compose.ayudando.yml --project-name ayudando ps

# Ver logs en tiempo real
docker compose -f docker-compose.ayudando.yml --project-name ayudando logs -f

# Reiniciar todos los servicios
docker compose -f docker-compose.ayudando.yml --project-name ayudando restart
```

### Shell en contenedores

```bash
# Backend (PHP)
docker exec -it ayudando_backend sh

# Frontend (Node)
docker exec -it ayudando_frontend sh

# Base de datos (psql)
docker exec -it shared_postgres psql -U postgres -d ayudando
```

### Laravel / Artisan

```bash
# Cualquier comando artisan
docker exec ayudando_backend php artisan <comando>

# Ejemplos comunes
docker exec ayudando_backend php artisan key:generate
docker exec ayudando_backend php artisan migrate
docker exec ayudando_backend php artisan migrate:fresh --seed
docker exec ayudando_backend php artisan config:clear
docker exec ayudando_backend php artisan cache:clear
docker exec ayudando_backend php artisan route:clear
docker exec ayudando_backend php artisan config:cache
docker exec ayudando_backend php artisan route:cache
```

### Base de datos

```bash
# Importar dump (formato .tar — NO usar psql)
docker exec -i shared_postgres pg_restore -U postgres -d ayudando --no-owner --no-acl < src/ayudando/ayudando.tar

# Para emergencias y fiscalizacion
docker exec -i shared_postgres pg_restore -U postgres -d emergencias --no-owner --no-acl < src/emergencias/emergencias.tar
docker exec -i shared_postgres pg_restore -U postgres -d fiscalizacion --no-owner --no-acl < src/fiscalizacion/fiscalizacion.tar
```

### Build de producción (Ionic)

La compilación web corre **dentro del contenedor**. El resultado queda en `src/<proyecto>/frontend/www/` gracias al bind-mount.

```bash
# El contenedor debe estar corriendo
docker exec ayudando_frontend ionic build --prod

# Con configuración Angular específica
docker exec ayudando_frontend ionic build --prod --configuration=production

# Verificar que el www/ fue generado
docker exec ayudando_frontend ls -lh /app/www
```

Para el proceso completo de build nativo (Android/iOS), firma y publicación en tiendas, ver [`MOBILE_BUILD.md`](./MOBILE_BUILD.md).

---

### Diagnóstico

```bash
docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.CPUPerc}}"

# Queries PostgreSQL lentas (> 200ms)
docker logs shared_postgres 2>&1 | grep "duration:"
```

### Reset completo de la base de datos

```bash
# ⚠️ Destructivo — elimina TODOS los datos de todos los proyectos
docker compose -f docker-compose.shared.yml down -v
docker compose -f docker-compose.shared.yml up -d
# Esperar que postgres esté healthy, luego:
docker exec -i shared_postgres pg_restore -U postgres -d ayudando --no-owner --no-acl < src/ayudando/ayudando.tar
```

### Conectar pgAdmin

Abrir http://localhost:5050 y crear un servidor con estos datos:

| Campo | Valor |
|---|---|
| Host | `postgres` ← nombre del servicio, **NO** `localhost` |
| Port | `5432` |
| Maintenance database | `postgres` |
| Username | `postgres` |
| Password | valor de `POSTGRES_PASSWORD` en `.env` |

---

## @ngx-formly — instalación opcional

`@ngx-formly` se instala directamente desde npm registry. La instalación es opcional y se activa por variable de entorno al levantar el proyecto.

### Instalación interactiva (recomendada)

Activar `INSTALL_FORMLY=yes` en `envs/<proyecto>.env` antes de levantar el contenedor, o usar el Generador de .env en el dashboard (`http://localhost:8090`) y activar el checkbox.

```bash
# En envs/ayudando.env:
INSTALL_FORMLY=yes
```

Luego levantar / reiniciar el contenedor:

```bash
docker compose -f docker-compose.ayudando.yml --project-name ayudando up -d
```

### Instalación manual vía env var

```bash
INSTALL_FORMLY=yes docker compose -f docker-compose.ayudando.yml --project-name ayudando up -d
```

### Vía dashboard (generador de .env)

En `http://localhost:8090` hay un **Generador de .env** con checkbox por proyecto. Activar el checkbox genera `envs/<proyecto>.env` con `INSTALL_FORMLY=yes`.

### Cómo funciona

Al arrancar, `docker/frontend/entrypoint.sh` verifica:

1. `INSTALL_FORMLY=yes`
2. `node_modules/@ngx-formly` **no** existe todavía

Si ambas condiciones se cumplen, ejecuta `npm install @ngx-formly/core --legacy-peer-deps`. En arranques posteriores el paquete ya está y el paso se omite.

### Verificar instalación

```bash
docker exec ayudando_frontend ls node_modules/@ngx-formly
```

---

## Dashboard

El dashboard se levanta automáticamente con `docker-compose.shared.yml`:

**http://localhost:8090**

Muestra tarjetas para cada proyecto con:
- **Estado en tiempo real** (activo / inactivo) — verificado cada 30 segundos
- **Links al frontend y backend** — habilitados solo si el servicio responde
- **Guía de configuración** paso a paso
- **Sección de problemas frecuentes**

El nginx del dashboard detecta la IP del host al iniciarse y hace proxy interno a cada puerto, sin CORS ni cambios en los proyectos.

---

## Make — atajos opcionales

`make` es una herramienta que permite definir comandos cortos como aliases. **No es requerido** — todos los comandos de este repo funcionan con Docker directamente.

### Instalación

- **Windows**: incluido en [Git for Windows](https://gitforwindows.org/), o instalar con `choco install make` ([Chocolatey](https://chocolatey.org/))
- **WSL / Linux**: `sudo apt install make` o `sudo dnf install make`
- **macOS**: incluido con Xcode Command Line Tools (`xcode-select --install`)

Verificar: `make --version`

### Referencia de comandos

```bash
# ─── Setup interactivo ────────────────────────────────────────────────────────
make setup    PROJECT=ayudando    # scripts/setup.sh — pregunta por @ngx-formly

# ─── Ciclo de vida ────────────────────────────────────────────────────────────
make up       PROJECT=ayudando    # docker compose ... up -d
make down     PROJECT=ayudando    # docker compose ... down
make build    PROJECT=ayudando    # docker compose ... build --no-cache
make restart  PROJECT=ayudando    # docker compose ... restart
make logs     PROJECT=ayudando    # docker compose ... logs -f
make ps       PROJECT=ayudando    # docker compose ... ps

# ─── Shell ────────────────────────────────────────────────────────────────────
make shell-backend  PROJECT=ayudando  # docker exec -it ayudando_backend sh
make shell-frontend PROJECT=ayudando  # docker exec -it ayudando_frontend sh
make shell-db       PROJECT=ayudando  # docker exec -it shared_postgres psql ...

# ─── Artisan ──────────────────────────────────────────────────────────────────
make artisan    cmd="migrate:status" PROJECT=ayudando
make migrate    PROJECT=ayudando
make fresh      PROJECT=ayudando
make cache-clear PROJECT=ayudando
make cache-warm  PROJECT=ayudando

# ─── Base de datos ────────────────────────────────────────────────────────────
make db-import  PROJECT=ayudando

# ─── Diagnóstico ──────────────────────────────────────────────────────────────
make mem-stats
make logs-slow PROJECT=ayudando

# ─── GPU (opcional) ───────────────────────────────────────────────────────────
make up-gpu    PROJECT=ayudando
make down-gpu  PROJECT=ayudando
make gpu-check PROJECT=ayudando
```

El proyecto válido es uno de: `ayudando`, `emergencias`, `fiscalizacion`.

---

## Variables de entorno

Los archivos de entorno están separados en dos niveles:

- **`.env`** — infraestructura compartida (postgres, pgAdmin, puertos host)
- **`envs/<proyecto>.env`** — secretos de cada proyecto (APP_KEY, JWT, SMTP, etc.)

Docker Compose inyecta ambos al contenedor via `env_file`. Las variables en `envs/<proyecto>.env` llegan **sin prefijo** directamente a Laravel y al entrypoint.

### `.env` — Infraestructura compartida

| Variable | Default | Descripción |
|---|---|---|
| `POSTGRES_USER` | `postgres` | Usuario del servidor PostgreSQL |
| `POSTGRES_PASSWORD` | — | **Requerido** |
| `PGADMIN_EMAIL` | `admin@local.dev` | Email de acceso a pgAdmin |
| `PGADMIN_PASSWORD` | — | **Requerido** |
| `APP_ENV` | `local` | Entorno Laravel |
| `APP_DEBUG` | `true` | Modo debug |
| `MAIL_PORT` | `465` | Puerto SMTP global |
| `MAIL_ENCRYPTION` | `tls` | Cifrado SMTP global |
| `<PROYECTO>_NGINX_PORT` | 8080/81/82 | Puerto host del backend |
| `<PROYECTO>_FRONTEND_PORT` | 4200/01/02 | Puerto host del frontend |

### `envs/<proyecto>.env` — Secretos por proyecto

| Variable | Descripción |
|---|---|
| `APP_KEY` | Clave de cifrado Laravel (`php artisan key:generate`) |
| `JWT_SECRET` | Secreto JWT (mín. 64 chars) |
| `MAIL_HOST` | Servidor SMTP |
| `MAIL_USERNAME` | Usuario SMTP |
| `MAIL_PASSWORD` | Contraseña SMTP |
| `INSTALL_FORMLY` | `yes` instala `@ngx-formly/core` via npm al primer arranque |

---

## Puertos

| Servicio | Ayudando | Emergencias | Fiscalización |
|---|---|---|---|
| Backend (Nginx) | 8080 | 8081 | 8082 |
| Frontend (Angular) | 4200 | 4201 | 4202 |
| **Compartido** | | | |
| PostgreSQL | 5432 | | |
| pgAdmin | 5050 | | |
| Dashboard | 8090 | | |

Todos los puertos son sobreescribibles en `.env`.

---

## Agregar un nuevo proyecto

### 1. Asignar puertos libres

| Servicio | Puerto sugerido |
|---|---|
| Backend (Nginx) | 8083 |
| Frontend | 4203 |

### 2. Crear `docker-compose.<proyecto>.yml`

Copiar `docker-compose.ayudando.yml` y reemplazar:

- `ayudando` → nombre del nuevo proyecto en todos los campos
- Prefijo de variables: `AYUDANDO_` → `<NUEVOPROYECTO>_`
- Nombre de red: `ayudando_net` → `<nuevoproyecto>_net`
- Puertos default: `8080` → `8083`, `4200` → `4203`

### 3. Agregar el archivo `envs/<proyecto>.env.example`

```bash
cp envs/ayudando.env.example envs/nuevoproyecto.env.example
# Editar: APP_KEY, JWT_SECRET, MAIL_*, INSTALL_FORMLY
```

### 4. Registrar en el Makefile (si usás make)

```makefile
VALID_PROJECTS := ayudando emergencias fiscalizacion nuevoproyecto
```

### 5. Agregar al dashboard

En `docker/dashboard/index.html`: copiar una tarjeta existente, cambiar `id`, nombre, puertos y color. Agregar el sistema al array `SYSTEMS` del script JS.

En `docker/dashboard/nginx.conf.template`: agregar dos bloques `location` para `/health/<nuevoproyecto>/frontend` y `/health/<nuevoproyecto>/backend`.

Reiniciar el dashboard:

```bash
docker compose -f docker-compose.shared.yml restart dashboard
```

### 6. Verificar

```bash
docker compose -f docker-compose.nuevoproyecto.yml --project-name nuevoproyecto build --no-cache
docker compose -f docker-compose.nuevoproyecto.yml --project-name nuevoproyecto up -d
docker compose -f docker-compose.nuevoproyecto.yml --project-name nuevoproyecto ps
```

---

## Solución de problemas

### Backend no conecta a la DB

```bash
docker compose -f docker-compose.shared.yml ps
# shared_postgres debe mostrar (healthy)
```

Causa más común: `POSTGRES_PASSWORD` vacío en `.env`.

### pgAdmin no puede conectar

- Host debe ser `postgres` (nombre del servicio), **no** `localhost`
- Puerto en pgAdmin: `5432` (interno)
- Maintenance database: `postgres`

### Puerto ya en uso

Sobreescribir en `.env`:

```env
AYUDANDO_NGINX_PORT=8083
AYUDANDO_FRONTEND_PORT=4203
```

Luego:

```bash
docker compose -f docker-compose.ayudando.yml --project-name ayudando down
docker compose -f docker-compose.ayudando.yml --project-name ayudando up -d
```

### Frontend no detecta cambios

```bash
docker compose -f docker-compose.ayudando.yml --project-name ayudando restart frontend
```

### Composer falla dentro del contenedor

```bash
docker exec -it ayudando_backend sh
composer install --ignore-platform-reqs -vvv
```

### Dashboard muestra todos los proyectos como inactivos

El proyecto no está corriendo, o reiniciar el dashboard para que resuelva la IP del host nuevamente:

```bash
docker compose -f docker-compose.shared.yml restart dashboard
```

### Las variables de entorno no se cargan

```bash
docker compose -f docker-compose.ayudando.yml --project-name ayudando config
```

Si las variables aparecen vacías: verificar que `envs/ayudando.env` existe y tiene valores correctos.
`env_file` en el compose carga `.env` (compartido) y `envs/ayudando.env` (proyecto) — ninguno puede faltar.

### @ngx-formly no se instala

Verificar que el contenedor tiene la variable seteada:

```bash
docker exec ayudando_frontend env | grep INSTALL_FORMLY
```

Si está en `no`, editar `envs/ayudando.env`, poner `INSTALL_FORMLY=yes`, y reiniciar:

```bash
docker compose -f docker-compose.ayudando.yml --project-name ayudando restart frontend
```

Si está en `no`, reiniciar con la variable correcta:

```bash
AYUDANDO_INSTALL_FORMLY=yes docker compose -f docker-compose.ayudando.yml --project-name ayudando up -d
```

Si `INSTALL_FORMLY=no`, reiniciar con la variable correcta:

```bash
docker compose -f docker-compose.ayudando.yml --project-name ayudando down
INSTALL_FORMLY=yes docker compose -f docker-compose.ayudando.yml --project-name ayudando up -d
```

O bien usar el script interactivo:

```bash
bash scripts/setup.sh ayudando
```
