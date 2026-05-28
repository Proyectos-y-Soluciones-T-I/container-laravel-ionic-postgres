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
7. [Dashboard](#dashboard)
8. [Make — atajos opcionales](#make--atajos-opcionales)
9. [Variables de entorno](#variables-de-entorno)
10. [Puertos](#puertos)
11. [Agregar un nuevo proyecto](#agregar-un-nuevo-proyecto)
12. [Solución de problemas](#solución-de-problemas)

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
├── .env.example                      ← Variables con prefijos por proyecto
├── .env                              ← Creado localmente desde .env.example (no commitear)
├── .gitattributes                    ← Normalización LF para todo el repo
├── Makefile                          ← Atajos opcionales (ver sección Make)
│
├── docker-compose.shared.yml         ← Infraestructura compartida (postgres, pgadmin, dashboard)
├── docker-compose.ayudando.yml       ← Servicios del proyecto Ayudando
├── docker-compose.emergencias.yml    ← Servicios del proyecto Emergencias
├── docker-compose.fiscalizacion.yml  ← Servicios del proyecto Fiscalización
├── docker-compose.gpu.yml            ← Overlay GPU opcional
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
│   │   ├── Dockerfile                ← Node 18 + Ionic CLI 7 + Angular CLI 17
│   │   └── entrypoint.sh             ← npm install + ng serve --poll 1000
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

### 3. Crear el `.env`

```bash
cp .env.example .env
```

Editar `.env` y completar las variables marcadas con `change_me`. Como mínimo:

| Variable | Descripción |
|---|---|
| `POSTGRES_PASSWORD` | Contraseña del servidor PostgreSQL compartido |
| `PGADMIN_PASSWORD` | Contraseña de pgAdmin |
| `<PREFIJO>_APP_KEY` | Clave Laravel — generar en el paso 6 |
| `<PREFIJO>_JWT_SECRET` | String aleatorio largo (mín. 64 chars) |
| `<PREFIJO>_MAIL_HOST/USERNAME/PASSWORD` | Credenciales SMTP |

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

```bash
docker compose -f docker-compose.ayudando.yml --project-name ayudando up -d
```

La primera vez tarda varios minutos — descarga imágenes, compila extensiones PHP e instala dependencias npm.

### 6. Generar APP_KEY

```bash
docker exec ayudando_backend php artisan key:generate
```

Copiar el valor generado (`base64:...`) y pegarlo en `.env` como `AYUDANDO_APP_KEY`.

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

### Diagnóstico

```bash
# Consumo de memoria y CPU por contenedor
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

`make` es una herramienta que permite definir comandos cortos como aliases. **No es requerido** — todos los comandos de este repo funcionan con Docker directamente. Es simplemente un atajo para no tipear el comando completo cada vez.

### Instalación

- **Windows**: incluido en [Git for Windows](https://gitforwindows.org/), o instalar con `choco install make` ([Chocolatey](https://chocolatey.org/))
- **WSL / Linux**: `sudo apt install make` o `sudo dnf install make`
- **macOS**: incluido con Xcode Command Line Tools (`xcode-select --install`)

Verificar: `make --version`

### Cómo funciona

El `Makefile` en la raíz del repo traduce comandos cortos a comandos Docker completos:

```bash
make up PROJECT=ayudando
# equivale a:
docker compose -f docker-compose.ayudando.yml --project-name ayudando up -d
```

### Referencia de comandos

```bash
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

El `.env` usa **prefijos** para aislar las variables de cada proyecto.

### Infraestructura compartida

| Variable | Default | Descripción |
|---|---|---|
| `POSTGRES_USER` | `postgres` | Usuario del servidor PostgreSQL |
| `POSTGRES_PASSWORD` | — | **Requerido** |
| `PGADMIN_EMAIL` | `admin@local.dev` | Email de acceso a pgAdmin |
| `PGADMIN_PASSWORD` | — | **Requerido** |
| `POSTGRES_PORT` | `5432` | Puerto host de PostgreSQL |
| `PGADMIN_PORT` | `5050` | Puerto host de pgAdmin |
| `DASHBOARD_PORT` | `8090` | Puerto host del dashboard |

### Por proyecto

Prefijos: `AYUDANDO_`, `EMERGENCIAS_`, `FISCALIZACION_`

| Variable | Descripción |
|---|---|
| `<PREFIJO>_APP_KEY` | Clave de cifrado Laravel (`php artisan key:generate`) |
| `<PREFIJO>_JWT_SECRET` | Secreto JWT |
| `<PREFIJO>_MAIL_HOST` | Servidor SMTP |
| `<PREFIJO>_MAIL_USERNAME` | Usuario SMTP |
| `<PREFIJO>_MAIL_PASSWORD` | Contraseña SMTP |
| `<PREFIJO>_NGINX_PORT` | Puerto host del backend (default: 8080/81/82) |
| `<PREFIJO>_FRONTEND_PORT` | Puerto host del frontend (default: 4200/01/02) |

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

### 3. Agregar variables al `.env.example`

```env
NUEVOPROYECTO_APP_KEY=base64:GENERATE_WITH_php_artisan_key_generate
NUEVOPROYECTO_JWT_SECRET=GENERATE_A_STRONG_SECRET
NUEVOPROYECTO_MAIL_HOST=your.smtp.host
NUEVOPROYECTO_MAIL_USERNAME=your@email.com
NUEVOPROYECTO_MAIL_PASSWORD=change_me

NUEVOPROYECTO_NGINX_PORT=8083
NUEVOPROYECTO_FRONTEND_PORT=4203
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

Si las variables aparecen vacías: el `.env` no existe, tiene un typo, o el prefijo no coincide.
