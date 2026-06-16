# Multi-Project Docker — Specification

## Port Allocation

| Project | Nginx | Frontend | PostgreSQL | pgAdmin |
|---------|-------|----------|------------|---------|
| ayudando | 8080 | 4200 | 5432 | 5050 |
| emergencias | 8081 | 4201 | 5433 | 5051 |
| fiscalizacion | 8082 | 4202 | 5434 | 5052 |

---

## Capability: multi-project-compose

The system MUST support running any registered project via `docker compose -f docker-compose.base.yml -f docker-compose.<project>.yml` with a `PROJECT` environment variable selecting the active project.

### Requirement: Base Compose File

The system SHALL provide `docker-compose.base.yml` defining all five services (postgres, pgadmin, backend, nginx, frontend) with `${PROJECT}` variable substitution for container names, volume names, and network names.

#### Scenario: Single project startup

- GIVEN a project override file `docker-compose.ayudando.yml` exists
- WHEN `make up PROJECT=ayudando` is executed
- THEN Docker Compose starts all five services with `ayudando_` prefixed names
- AND no container name collisions occur

#### Scenario: Simultaneous projects

- GIVEN override files for `ayudando` and `emergencias` exist
- WHEN `make up PROJECT=ayudando` and `make up PROJECT=emergencias` are both running
- THEN all ten containers coexist without name or port conflicts

### Requirement: Per-Project Override Files

Each registered project SHALL have a `docker-compose.<project>.yml` file that sets `PROJECT`, assigns static ports per the allocation table, and may define project-specific service overrides.

#### Scenario: Override sets project env and ports

- GIVEN `docker-compose.emergencias.yml` exists
- WHEN it is layered on top of `docker-compose.base.yml`
- THEN `PROJECT=emergencias` is set
- AND nginx binds to port 8081, frontend to 4201, postgres to 5433, pgadmin to 5051

### Requirement: Entrypoint Project Awareness

Entrypoint scripts MUST read the `PROJECT` environment variable for log prefixes and source path resolution (`/var/www/html/src/${PROJECT}/`) instead of hardcoded values.

#### Scenario: Backend entrypoint uses PROJECT path

- GIVEN `PROJECT=emergencias` is set in the container environment
- WHEN the backend entrypoint runs `composer install`
- THEN it operates inside `/var/www/html/src/emergencias/`

---

## Capability: makefile-selector

The Makefile SHALL parameterize all orchestration targets with a `PROJECT` variable. Every target MUST fail with a clear error if `PROJECT` is unset.

### Requirement: PROJECT-Parameterized Targets

The following targets MUST accept `PROJECT=<name>`: `up`, `down`, `build`, `logs`, `shell-backend`, `shell-frontend`, `shell-db`, `migrate`, `fresh`, `artisan`, `cache-clear`.

#### Scenario: Target with PROJECT provides correct compose flags

- GIVEN `PROJECT=ayudando` is specified
- WHEN `make up PROJECT=ayudando` runs
- THEN the command resolves to `docker compose -f docker-compose.base.yml -f docker-compose.ayudando.yml up -d`

#### Scenario: Missing PROJECT produces error

- GIVEN no `PROJECT` is provided
- WHEN `make up` runs without `PROJECT=`
- THEN the Makefile prints an error message telling the user to specify `PROJECT=<name>`
- AND exits with non-zero code

---

## Capability: project-dashboard

The system SHALL provide a static HTML page at `docker/dashboard/index.html` listing all registered projects with their port links.

### Requirement: Dashboard Listing

The dashboard MUST display each project name alongside clickable links for nginx, frontend, postgres, and pgadmin ports per the allocation table.

#### Scenario: Browse dashboard for a project

- GIVEN the dashboard HTML file exists
- WHEN a user opens `http://localhost:8080` (or any project's nginx port) and navigates to the dashboard
- THEN they see links for ayudando, emergencias, and fiscalizacion with correct port numbers

### Requirement: Dashboard Served by Nginx

The dashboard page MAY be served by any project's nginx container at a well-known path (e.g., `/dashboard/`).

#### Scenario: Nginx serves dashboard

- GIVEN `make up PROJECT=ayudando` is running
- WHEN a user requests `http://localhost:8080/dashboard/`
- THEN nginx returns the static HTML page from `docker/dashboard/index.html`

---

## Capability: gitignore-isolation

The entire `src/` directory MUST be gitignored. No subdirectory of `src/` SHALL ever be tracked by this repository.

### Requirement: Full src/ Exclusion

The `.gitignore` MUST contain a rule that excludes `src/` entirely (not `src/*/` or individual project directories).

#### Scenario: Git ignores all src content

- GIVEN `.gitignore` contains `src/`
- WHEN `src/ayudando/`, `src/emergencias/`, or any future `src/<project>/` directory exists
- THEN `git status` does not list any files under `src/`

#### Scenario: No accidental tracking on project switch

- GIVEN `src/emergencias/` contains application source code
- WHEN the user runs `git add .`
- THEN nothing under `src/emergencias/` is staged