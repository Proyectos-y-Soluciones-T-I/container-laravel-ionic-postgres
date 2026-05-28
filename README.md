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
6. [Levantar el entorno](#levantar-el-entorno)
7. [Dashboard](#dashboard)
8. [Comandos Make](#comandos-make)
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
├── Makefile                          ← Comandos rápidos
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
│       └── nginx.conf                ← Nginx del dashboard + proxies de health check
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
- `make` (recomendado — incluido en Git for Windows, Chocolatey o WSL)
- 8 GB RAM recomendados (6 GB mínimo)

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
| `<PREFIJO>_APP_KEY` | Clave Laravel — generar en el paso 5 |
| `<PREFIJO>_JWT_SECRET` | String aleatorio largo |
| `<PREFIJO>_MAIL_HOST/USERNAME/PASSWORD` | Credenciales SMTP |

### 4. Levantar la infraestructura compartida

```bash
docker compose -f docker-compose.shared.yml up -d
```

Verificar que postgres esté healthy antes de continuar:

```bash
docker compose -f docker-compose.shared.yml ps
# shared_postgres debe mostrar (healthy)
```

### 5. Levantar un proyecto

```bash
make up PROJECT=ayudando
```

La primera vez tarda varios minutos — descarga imágenes, compila extensiones PHP e instala dependencias npm.

### 6. Generar APP_KEY

```bash
make artisan cmd="key:generate" PROJECT=ayudando
```

Copiar el valor generado y pegarlo en `.env` como `AYUDANDO_APP_KEY`.

### 7. Importar la base de datos

```bash
make db-import PROJECT=ayudando
```

> El dump está en formato `.tar` — se importa con `pg_restore`, **no** con `psql`.

### 8. Verificar que todo está corriendo

```bash
make ps PROJECT=ayudando
```

El frontend tarda unos minutos adicionales en compilar. Para seguir el progreso:

```bash
make logs PROJECT=ayudando
# Esperar: ✔ Compiled successfully.
```

---

## Levantar el entorno

### Infraestructura compartida (una sola vez)

```bash
# Levantar postgres + pgAdmin + dashboard
docker compose -f docker-compose.shared.yml up -d

# Bajar (solo si querés resetear — pierde los datos si usás down -v)
docker compose -f docker-compose.shared.yml down
```

### Proyectos (uno a la vez)

```bash
# Levantar
make up PROJECT=ayudando
make up PROJECT=emergencias
make up PROJECT=fiscalizacion

# Bajar
make down PROJECT=ayudando
```

### Conectar pgAdmin al servidor de base de datos

Al crear el servidor en pgAdmin, usar estos datos:

| Campo | Valor |
|---|---|
| Host | `postgres` ← nombre del servicio Docker, **no** `localhost` |
| Port | `5432` |
| Maintenance database | `postgres` |
| Username | `postgres` |
| Password | valor de `POSTGRES_PASSWORD` en `.env` |

---

## Dashboard

El dashboard se levanta automáticamente con `docker-compose.shared.yml` y está disponible en:

**http://localhost:8090**

Muestra tarjetas para cada proyecto con:
- Estado en tiempo real (activo / inactivo) verificado cada 30 segundos
- Links al frontend y al backend — habilitados solo si el servicio está corriendo
- Guía de configuración paso a paso
- Sección de problemas frecuentes

### Cómo funciona el health check

El nginx del dashboard hace proxy interno a los puertos del host usando `host.docker.internal`. Esto evita CORS y no requiere ningún cambio en los proyectos.

```
browser → GET localhost:8090/health/ayudando/frontend
            ↓
        nginx (dashboard, dentro de Docker)
            ↓ proxy_pass
        host.docker.internal:4200
            ↓
        ✅ 200 activo  /  ❌ 502 inactivo
```

---

## Comandos Make

```bash
# ─── Ciclo de vida ────────────────────────────────────────────────────────────
make up       PROJECT=ayudando    # Levantar
make down     PROJECT=ayudando    # Bajar
make build    PROJECT=ayudando    # Reconstruir imágenes (sin caché)
make restart  PROJECT=ayudando    # Reiniciar servicios
make logs     PROJECT=ayudando    # Logs en tiempo real
make ps       PROJECT=ayudando    # Estado de contenedores

# ─── Shell en contenedores ────────────────────────────────────────────────────
make shell-backend  PROJECT=ayudando  # Shell PHP
make shell-frontend PROJECT=ayudando  # Shell Node
make shell-db       PROJECT=ayudando  # psql

# ─── Laravel / Artisan ────────────────────────────────────────────────────────
make artisan    cmd="migrate:status" PROJECT=ayudando  # Cualquier comando artisan
make migrate    PROJECT=ayudando                       # php artisan migrate
make fresh      PROJECT=ayudando                       # migrate:fresh --seed
make cache-clear PROJECT=ayudando                      # Limpiar config, cache y rutas
make cache-warm  PROJECT=ayudando                      # Pre-cachear config y rutas

# ─── Base de datos ────────────────────────────────────────────────────────────
make db-import  PROJECT=ayudando  # Importar dump .tar

# ─── Diagnóstico ──────────────────────────────────────────────────────────────
make mem-stats                    # Consumo de memoria por contenedor
make logs-slow PROJECT=ayudando   # Queries PostgreSQL > 200ms

# ─── GPU (opcional) ───────────────────────────────────────────────────────────
make up-gpu    PROJECT=ayudando   # Levantar con soporte GPU
make down-gpu  PROJECT=ayudando   # Bajar y limpiar override GPU
make gpu-check PROJECT=ayudando   # Verificar GPU dentro del contenedor
```

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

Cada proyecto tiene su conjunto con prefijo `AYUDANDO_`, `EMERGENCIAS_` o `FISCALIZACION_`:

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
- Puertos en los defaults: `8080` → `8083`, `4200` → `4203`

### 3. Agregar variables al `.env.example`

```env
# ============================================================
# NUEVOPROYECTO
# ============================================================
NUEVOPROYECTO_APP_KEY=base64:GENERATE_WITH_php_artisan_key_generate
NUEVOPROYECTO_JWT_SECRET=GENERATE_A_STRONG_SECRET
NUEVOPROYECTO_MAIL_HOST=your.smtp.host
NUEVOPROYECTO_MAIL_USERNAME=your@email.com
NUEVOPROYECTO_MAIL_PASSWORD=change_me

NUEVOPROYECTO_NGINX_PORT=8083
NUEVOPROYECTO_FRONTEND_PORT=4203
```

### 4. Registrar en el Makefile

```makefile
VALID_PROJECTS := ayudando emergencias fiscalizacion nuevoproyecto
```

### 5. Agregar al dashboard

En `docker/dashboard/index.html`: copiar una tarjeta existente, cambiar el `id`, nombre, puertos y color.

En `docker/dashboard/nginx.conf`: agregar dos `location` blocks para `/health/<nuevoproyecto>/frontend` y `/health/<nuevoproyecto>/backend`.

### 6. Verificar

```bash
make build PROJECT=nuevoproyecto
make up PROJECT=nuevoproyecto
make ps PROJECT=nuevoproyecto
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
- Puerto en pgAdmin: `5432` (interno), no el puerto del `.env`
- Maintenance database: `postgres`

### Puerto ya en uso

Sobreescribir en `.env`:

```env
AYUDANDO_NGINX_PORT=8083
AYUDANDO_FRONTEND_PORT=4203
```

Luego `make down PROJECT=ayudando && make up PROJECT=ayudando`.

### Frontend no detecta cambios de archivos

```bash
make restart PROJECT=ayudando
```

El dev server usa `--poll 1000` para Windows. Si sigue sin funcionar, reiniciar el contenedor.

### Composer falla dentro del contenedor

```bash
make shell-backend PROJECT=ayudando
composer install --ignore-platform-reqs -vvv
```

### Reset completo de la base de datos

```bash
# ⚠️ Destruye TODOS los datos de todos los proyectos
docker compose -f docker-compose.shared.yml down -v
docker compose -f docker-compose.shared.yml up -d
make db-import PROJECT=ayudando
```

### Las variables de entorno no se cargan

```bash
# Verificar que Docker Compose ve los valores correctos
docker compose -f docker-compose.shared.yml config
```

Si las variables aparecen vacías: el `.env` no existe, tiene un typo en el nombre, o el prefijo no coincide.
