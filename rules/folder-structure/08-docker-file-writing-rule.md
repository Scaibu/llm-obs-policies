---
agent_role: "Container Infrastructure & Docker Compliance Enforcer"
trigger: "ON_REFERENCE | ON_CONTEXT_LOAD | ON_DOCKERFILE_CREATION"
scope: "Production Dockerfiles, Multi-Stage Builds, Compose Manifests, Hardening, Base Registries, Security Scans"
mode: "Strict"
contract_version: "2.1"
enforcement: "Absolute & Non-Negotiable"
---

# Production Docker & Container Specification Contract (`deploy/docker/`)

> **Architectural Separation Principle:**  
> Container specifications operate across distinct infrastructure layers. They must **NEVER** be merged or configured arbitrarily:
> - **Base Images (`base/`):** Hardened, non-root, pinned digest, OS-level utilities (tini, CA certs, tzdata) updated via automated registries.
> - **Service Images (`service/`):** Multi-stage builds (`builder` -> `runtime`), strictly non-root, minimal attack surface, zero compilers/dev-deps in runtime.
> - **Composition (`compose/`):** Pinned project names, internal network isolation, explicit health checks, volume ownership, and read-only filesystems.

---

# PART I: STRICT GUARDRAILS (WHAT NOT TO DO AT ALL)

0. **STRICT NON-ASSUMPTION & EXISTING BASE INVARIANT**:
   - Strictly never assume anything.
   - Always verify if an established base image digest or hardened base exists in `deploy/docker/base/registry.yaml` before creating or referencing new containers.
   - Strictly never create anything extra or unsolicited unless explicitly requested by the user.

These are non-negotiable negative constraints and architectural invariants. Systems, AI agents, and engineers MUST review these first before taking any action:

1. **NEVER Use Floating Tags or Unpinned Images:** `FROM ...:latest` or unpinned tags without cryptographic digests (`@sha256:...`) are strictly prohibited in production specifications. Every base image must be pinned to an immutable digest.
2. **NEVER Run Containers as Root:** Containers must drop all privileges and run as an explicit unprivileged user (`USER 10001:10001` or `USER app`). Final stages must NEVER contain `USER root`.
3. **NEVER Bake Environment Secrets into Images:** Never use `ARG` or `ENV` for sensitive tokens, passwords, private keys, or credentials. Build-time secrets must strictly use `RUN --mount=type=secret,id=...` and runtime secrets must use mounted secret files (`/run/secrets/`).
4. **NEVER Expose Internal Infrastructure Databases to the Host:** Database (`db`), cache (`cache`), and queue brokers must join isolated `internal: true` backend networks without host port publishing (`ports:`). Only ingress proxies (`proxy`) or local loopback dev profiles (`127.0.0.1:...`) may publish ports.
5. **NEVER Use Mutable `ADD` or Unchecked Remote Downloads:** `ADD` is strictly forbidden. Unchecked `curl ... | sh` or `wget ... | bash` is strictly banned. Use verified package managers or checksum-verified downloads in builder stages.
6. **NEVER Include Compilers or Package Caches in Runtime Images:** Final runtime stages must contain zero compilers (gcc, g++, make), git binaries, test runners, or package manager cache directories (`/root/.cache`, `/var/lib/apt/lists/*`).
7. **NEVER Put `HEALTHCHECK` in Dockerfiles (Compose & Orchestrator Level Invariant):** Do not declare `HEALTHCHECK` inside production Dockerfiles because Kubernetes and cloud orchestrators ignore it or flap inappropriately. Healthchecks and probes are defined in compose manifests (`deploy/docker/compose/`), K8s manifests (`deploy/k8s/`), and Helm charts (`deploy/helm/`).
8. **NEVER Use `docker compose down -v` in Production:** The `-v` flag destroys named volumes, including stateful database storage. Scripts and CI must block `-v` on production targets.
9. **NEVER Use Permissive Security Caps or Privileged Mode:** `privileged: true`, `cap_add: [ALL]`, and `network_mode: host` are strictly prohibited. Always use `cap_drop: [ALL]`, `security_opt: ["no-new-privileges:true"]`, and `read_only: true` with `/tmp` mounted via tmpfs.
10. **NEVER Swallow Signals (Mandatory PID 1 Init Wrapper):** Never run application processes directly via shell form (`CMD npm start` or `CMD python ...`). Always use exec form (`CMD ["python", ...]`) wrapped by an explicit init supervisor (`ENTRYPOINT ["/usr/bin/tini", "--"]`) with `STOPSIGNAL SIGTERM` to ensure graceful signal propagation and zombie reaping.

---

# PART II: DOCKER ARTIFACT STRUCTURE & FILE LAYOUT

## 1. Directory Tree & Canonical File Roles

All container definitions live under `deploy/docker/` following an explicit hierarchy:

| Step # | Artifact Role | Path | Purpose |
|:------:|---------------|------|---------|
| **01** | Registry Manifest | `deploy/docker/base/registry.yaml` | Immutable cryptographic digests (`@sha256`), upstream registries, and update policies. Single source of truth. |
| **02** | Base Runtime | `deploy/docker/base/Dockerfile.base` | Hardened, minimal runtime base containing `tini`, CA certs, tzdata, non-root user creation, and tmpfs permissions. |
| **03** | Service Prod Build | `deploy/docker/service/Dockerfile` | Production multi-stage build: `builder` stage compiles dependencies; final `runtime` stage copies artifacts with zero dev tools. |
| **04** | Service Dev Build | `deploy/docker/service/Dockerfile.dev` | Development image supporting live code watchers (`develop.watch`). Never pushed to production registries. |
| **05** | Shared Infra Compose | `deploy/docker/compose/docker-compose.infra.yml` | Stateful shared backing services (PostgreSQL, Valkey/Redis, Kafka, Caddy proxy), isolated networks, volumes, and secrets. |
| **06** | Single Service Compose| `deploy/docker/compose/docker-compose.single.yml` | Isolated composition of one application service plus shared infrastructure. Includes local `dev` profile. |
| **07** | Polyglot Service Compose| `deploy/docker/compose/docker-compose.polyglot.yml` | Multi-service composition (Python, Node, Go) sharing backing infrastructure and internal networking. |
| **08** | Ingress & Network Map | `deploy/topology/network_map.yaml` | Declares authoritative service hostnames, exposed internal ports, and communication protocols. |
| **09** | Release Scripts | `deploy/release/deploy.sh`, `rollback.sh` | Deterministic deployment and rollback executing by image digest only. |

Build context is ALWAYS the **repository root**, governed by the root `.dockerignore`.

---

# PART III: CANONICAL SPECIFICATIONS & BLUEPRINTS

## 1. `deploy/docker/base/registry.yaml` (Immutable Base Registry)

```yaml
version: 1
mirror: <your-registry>/mirror
bases:
  python:
    upstream: python:3.12.7-slim-bookworm
    digest: sha256:<digest>
    output: <your-registry>/base-python
    healthcheck_style: exec-python
  node:
    upstream: node:22.11.0-slim
    digest: sha256:<digest>
    output: <your-registry>/base-node
    healthcheck_style: exec-node
  go:
    upstream: debian:bookworm-slim
    digest: sha256:<digest>
    output: <your-registry>/base-go
    healthcheck_style: binary-subcommand
policy:
  max_base_age_days: 30
  scan: { tool: trivy, fail_on: [HIGH, CRITICAL], ignore_unfixed: true }
  sign: cosign
```

---

## 2. `deploy/docker/base/Dockerfile.base` (Hardened Base Image)

```dockerfile
# syntax=docker/dockerfile:1.7
ARG RUNTIME_IMAGE
FROM ${RUNTIME_IMAGE} AS base

ARG APP_UID=10001
ARG APP_GID=10001

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates tzdata tini \
 && rm -rf /var/lib/apt/lists/* \
 && groupadd --gid ${APP_GID} app \
 && useradd  --uid ${APP_UID} --gid ${APP_GID} --no-create-home --shell /usr/sbin/nologin app \
 && mkdir -p /app && chown ${APP_UID}:${APP_GID} /app

ENV LANG=C.UTF-8 TZ=UTC HOME=/tmp

WORKDIR /app
USER ${APP_UID}:${APP_GID}

ENTRYPOINT ["/usr/bin/tini", "--"]
STOPSIGNAL SIGTERM
```

---

## 3. `deploy/docker/service/Dockerfile` (Production Multi-Stage Build)

```dockerfile
# syntax=docker/dockerfile:1.7
ARG BASE_IMAGE
ARG BUILDER_IMAGE

# ---------- Stage 1: Builder (Compilers and build-time caches live ONLY here) ----------
FROM ${BUILDER_IMAGE} AS builder
ARG SERVICE_PATH
ENV PIP_DISABLE_PIP_VERSION_CHECK=1 PIP_NO_CACHE_DIR=0
WORKDIR /build

RUN python -m venv /opt/venv
COPY ${SERVICE_PATH}/requirements.txt ./
RUN --mount=type=cache,target=/root/.cache/pip \
    /opt/venv/bin/pip install --require-hashes -r requirements.txt

# ---------- Stage 2: Runtime (Hardened minimal image, MUST be the final stage) ----------
FROM ${BASE_IMAGE} AS runtime
ARG SERVICE_PATH
ARG UID=10001
ARG GID=10001

ENV PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1 PATH="/opt/venv/bin:${PATH}"

COPY --from=builder /opt/venv /opt/venv
COPY --chown=${UID}:${GID} ${SERVICE_PATH}/src/ ./src/

ARG GIT_SHA=unknown
ARG BUILD_DATE=unknown
LABEL org.opencontainers.image.source="https://github.com/<org>/<repo>" \
      org.opencontainers.image.revision="${GIT_SHA}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.title="${SERVICE_PATH}"

USER ${UID}:${GID}
EXPOSE 8000
CMD ["python", "-m", "uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

---

## 4. `deploy/docker/service/Dockerfile.dev` (Development Image with Live Sync)

```dockerfile
# syntax=docker/dockerfile:1.7
# DEV ONLY: Never pushed to production registries
ARG BUILDER_IMAGE
FROM ${BUILDER_IMAGE} AS dev
ARG SERVICE_PATH
ENV PYTHONUNBUFFERED=1 PIP_DISABLE_PIP_VERSION_CHECK=1
WORKDIR /app

COPY ${SERVICE_PATH}/requirements.txt ./
RUN --mount=type=cache,target=/root/.cache/pip pip install -r requirements.txt

EXPOSE 8000
CMD ["python", "-m", "uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]
```

---

## 5. `.dockerignore` (Allowlist Strategy at Repo Root)

```
*
!services/**/src/**
!services/**/requirements.txt
!services/**/package.json
!services/**/package-lock.json
!services/**/go.mod
!services/**/go.sum
!services/**/cmd/**
**/__pycache__
**/*.pyc
**/node_modules
**/.env*
**/*.md
```

---

## 6. `deploy/docker/compose/docker-compose.infra.yml` (Stateful Infrastructure Backbone)

```yaml
name: ${COMPOSE_PROJECT_NAME:-myapp}

x-hardening: &hardening
  read_only: true
  cap_drop: [ALL]
  security_opt: ["no-new-privileges:true"]
  init: true
  pids_limit: 256
  restart: unless-stopped
  logging: &logging
    driver: local
    options: { max-size: "10m", max-file: "5" }

services:
  db:
    image: postgres:16.4-bookworm@sha256:<digest>
    restart: unless-stopped
    security_opt: ["no-new-privileges:true"]
    cap_drop: [ALL]
    cap_add: [CHOWN, SETUID, SETGID, FOWNER, DAC_OVERRIDE]
    networks: [backend]
    environment:
      POSTGRES_PASSWORD_FILE: /run/secrets/db_password
    secrets: [db_password]
    volumes: [pgdata:/var/lib/postgresql/data]
    shm_size: 256m
    stop_grace_period: 60s
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 3s
      retries: 5
      start_period: 20s
    deploy:
      resources:
        limits: { cpus: "2.0", memory: 1G }
    logging: *logging

  cache:
    <<: *hardening
    image: redis:7.4-bookworm@sha256:<digest>
    command: ["redis-server", "--maxmemory", "200mb", "--maxmemory-policy", "allkeys-lru", "--save", ""]
    networks: [backend]
    tmpfs: [/data]
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 3s
      retries: 5
      start_period: 5s
    deploy:
      resources:
        limits: { memory: 256M }

  proxy:
    <<: *hardening
    image: caddy:2.8-alpine@sha256:<digest>
    ports: ["80:80", "443:443"]
    networks: [frontend]
    volumes:
      - ${PROXY_CONFIG:?set PROXY_CONFIG to Caddyfile path}:/etc/caddy/Caddyfile:ro
      - caddy_data:/data
    tmpfs: [/config, /tmp]
    healthcheck:
      test: ["CMD", "wget", "-qO-", "--spider", "http://127.0.0.1:2019/config/"]
      interval: 15s
      timeout: 3s
      retries: 3
      start_period: 10s

networks:
  frontend: {}
  backend:
    internal: true
  egress: {}

volumes:
  pgdata:
    name: ${COMPOSE_PROJECT_NAME:-myapp}_pgdata
  caddy_data: {}

secrets:
  db_password:
    file: ${SECRETS_DIR:?set SECRETS_DIR}/db_password.txt
```

---

## 7. `deploy/docker/compose/docker-compose.single.yml` (Single Service Composition)

```yaml
include:
  - path: docker-compose.infra.yml

x-hardening: &hardening
  read_only: true
  cap_drop: [ALL]
  security_opt: ["no-new-privileges:true"]
  init: true
  pids_limit: 256
  restart: unless-stopped
  logging: { driver: local, options: { max-size: "10m", max-file: "5" } }

services:
  migrate:
    <<: *hardening
    restart: "no"
    image: ${REGISTRY:?}/app@${APP_DIGEST:?set APP_DIGEST}
    command: ["python", "-m", "src.migrate"]
    depends_on:
      db: { condition: service_healthy }
    networks: [backend]
    secrets: [db_password]
    tmpfs: [/tmp]

  app:
    <<: *hardening
    image: ${REGISTRY:?}/app@${APP_DIGEST:?set APP_DIGEST}
    depends_on:
      db:      { condition: service_healthy, restart: true }
      cache:   { condition: service_healthy, restart: true }
      migrate: { condition: service_completed_successfully }
    networks: [frontend, backend]
    expose: ["8000"]
    environment:
      DB_HOST: db
      CACHE_HOST: cache
      DB_PASSWORD_FILE: /run/secrets/db_password
    secrets: [db_password]
    tmpfs: [/tmp]
    stop_grace_period: 30s
    healthcheck:
      test: ["CMD", "python", "-c", "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8000/healthz',timeout=2).status==200 else 1)"]
      interval: 15s
      timeout: 3s
      retries: 3
      start_period: 30s
    deploy:
      resources:
        limits:       { cpus: "1.0", memory: 512M }
        reservations: { memory: 256M }
    ulimits:
      nofile: { soft: 65535, hard: 65535 }

  app-dev:
    profiles: [dev]
    build:
      context: ../../..
      dockerfile: deploy/docker/service/Dockerfile.dev
      args:
        BUILDER_IMAGE: ${BUILDER_IMAGE:?}
        SERVICE_PATH: ${SERVICE_PATH:?}
    depends_on:
      db:    { condition: service_healthy }
      cache: { condition: service_healthy }
    networks: [backend]
    ports: ["127.0.0.1:8000:8000"]
    environment:
      DB_HOST: db
      CACHE_HOST: cache
      DB_PASSWORD_FILE: /run/secrets/db_password
    secrets: [db_password]
    develop:
      watch:
        - { action: sync,         path: ../../../${SERVICE_PATH}/src,    target: /app/src }
        - { action: sync+restart, path: ../../../${SERVICE_PATH}/config, target: /app/config }
        - { action: rebuild,      path: ../../../${SERVICE_PATH}/requirements.txt }
```

---

## 8. `deploy/docker/compose/docker-compose.polyglot.yml` (Multi-Language Deployment)

```yaml
include:
  - path: docker-compose.infra.yml

x-hardening: &hardening
  read_only: true
  cap_drop: [ALL]
  security_opt: ["no-new-privileges:true"]
  init: true
  pids_limit: 256
  restart: unless-stopped
  logging: { driver: local, options: { max-size: "10m", max-file: "5" } }

x-app-common: &app-common
  <<: *hardening
  networks: [frontend, backend]
  tmpfs: [/tmp]
  stop_grace_period: 30s
  ulimits: { nofile: { soft: 65535, hard: 65535 } }

services:
  migrate:
    <<: *hardening
    restart: "no"
    image: ${REGISTRY:?}/orders-py@${ORDERS_PY_DIGEST:?}
    command: ["python", "-m", "src.migrate"]
    depends_on: { db: { condition: service_healthy } }
    networks: [backend]
    secrets: [db_password]
    tmpfs: [/tmp]

  orders-py:
    <<: *app-common
    image: ${REGISTRY:?}/orders-py@${ORDERS_PY_DIGEST:?}
    depends_on:
      db:      { condition: service_healthy, restart: true }
      migrate: { condition: service_completed_successfully }
    expose: ["8000"]
    secrets: [db_password]
    environment: { DB_HOST: db, DB_PASSWORD_FILE: /run/secrets/db_password }
    healthcheck:
      test: ["CMD", "python", "-c", "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8000/healthz',timeout=2).status==200 else 1)"]
      interval: 15s
      timeout: 3s
      retries: 3
      start_period: 30s
    deploy: { resources: { limits: { cpus: "1.0", memory: 512M } } }

  gateway-node:
    <<: *app-common
    image: ${REGISTRY:?}/gateway-node@${GATEWAY_NODE_DIGEST:?}
    depends_on:
      orders-py: { condition: service_healthy, restart: true }
      cache:     { condition: service_healthy, restart: true }
    expose: ["3000"]
    environment:
      NODE_OPTIONS: "--max-old-space-size=384"
      ORDERS_URL: http://orders-py:8000
    healthcheck:
      test: ["CMD", "node", "-e", "fetch('http://127.0.0.1:3000/healthz').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"]
      interval: 15s
      timeout: 3s
      retries: 3
      start_period: 20s
    deploy: { resources: { limits: { cpus: "1.0", memory: 512M } } }

  billing-go:
    <<: *app-common
    image: ${REGISTRY:?}/billing-go@${BILLING_GO_DIGEST:?}
    depends_on:
      db: { condition: service_healthy, restart: true }
    networks: [backend, egress]
    expose: ["9000"]
    secrets: [db_password]
    environment: { GOMEMLIMIT: "200MiB", DB_PASSWORD_FILE: /run/secrets/db_password }
    healthcheck:
      test: ["CMD", "/app/svc", "healthcheck"]
      interval: 15s
      timeout: 3s
      retries: 3
      start_period: 10s
    deploy: { resources: { limits: { cpus: "0.5", memory: 256M } } }
```

---

# PART IV: OPERATIONAL EDGE CASES & MITIGATION

1. **Unhealthy State Handling:** Plain Docker does not auto-restart containers failing healthchecks. Autoheal agents or Kubernetes orchestration probes must be active.
2. **UFW Port Bypass:** Docker creates direct iptables rules. Never bind raw container ports directly to host interfaces—route all external ingress through the proxy.
3. **Missing Compose Variables:** Always use strict default-checking syntax `${VAR:?error_message}` to prevent silent empty-string fallbacks.
4. **Volume Destruction (`-v`):** `docker compose down -v` permanently wipes persistent database volumes. Banned in all production scripts and CI pipelines.
5. **Read-Only Root Filesystem:** Applications expecting write access to `/tmp` or `$HOME` must be backed by memory tmpfs mounts (`tmpfs: [/tmp]`).
6. **Internal Egress Isolation:** Services requiring external 3rd-party APIs (Stripe, OpenAI, OAuth) must join an explicit `egress` network; internal microservices remain strictly quarantined in `backend` with `internal: true`.
7. **Volume UID/GID Permissions:** Non-root UID `10001` cannot write to root-owned host directories. Prefer named docker volumes initialized with proper ownership.
8. **Daemon Auto-Start:** Ensure `systemctl enable docker` and configure daemon `live-restore` to survive daemon restarts without taking down containers.
9. **Log & Storage Exhaustion:** Unrotated container logs will fill the host disk. Mandatory `driver: local` with `max-size: "10m"` and `max-file: "5"`.
10. **Application OOM Crash Prevention:** Set application runtime memory caps (`--max-old-space-size`, `GOMEMLIMIT`, JVM heap) to 75% of the container hard memory limit to guarantee graceful garbage collection rather than unceremonious SIGKILL by the kernel OOM killer.
11. **Graceful Shutdown Duration:** Set `stop_grace_period: 30s` (or 60s for databases) to exceed the slowest in-flight request deadline, allowing connection draining.
12. **Architecture Cross-Compilation:** Always build production targets with `--platform linux/amd64` to prevent Apple Silicon `arm64` local builds failing with `exec format error` in production.

---

# PART V: CI/CD ENFORCEMENT & COMPLIANCE GATES

Every release pipeline must pass these sequential checks before image signing or deployment:

```bash
# 1. Static Linting & Compose Verification
hadolint deploy/docker/base/Dockerfile.base deploy/docker/service/Dockerfile deploy/docker/service/Dockerfile.dev
for f in deploy/docker/compose/docker-compose.*.yml; do
  docker compose -f "$f" config --quiet || exit 1
done

# 2. Build Multi-Arch with Provenance and SBOM
docker buildx build --platform linux/amd64 --provenance=true --sbom=true -f deploy/docker/service/Dockerfile ...

# 3. Vulnerability Scanning & Structural Testing
dockle --exit-code 1 "$IMAGE"
trivy image --exit-code 1 --severity HIGH,CRITICAL --ignore-unfixed "$IMAGE"
container-structure-test test --image "$IMAGE" --config deploy/docker/tests/structure.yaml

# 4. Production Smoke Verification
docker run --rm -d --name smoke --read-only --cap-drop ALL --security-opt no-new-privileges \
  --user 10001:10001 --tmpfs /tmp "$IMAGE"
docker stop -t 30 smoke; test "$(docker inspect -f '{{.State.ExitCode}}' smoke)" = 0

# 5. Forbidden Pattern Guardrail Audit
grep -RInE 'privileged:|network_mode: *host|docker\.sock|:latest|--profile dev|down +-v|USER root' deploy/docker deploy/release

# 6. Cryptographic Signing by Digest
cosign sign --yes "$REGISTRY/$NAME@$DIGEST"
```

---

# PART VI: DEPLOYMENT & ROLLBACK CONTRACT (`deploy/release`)

### `deploy.sh`
1. Require explicit `APP_DIGEST`; refuse mutable tags.
2. Verify cryptographic signature via `cosign verify`.
3. Pull images: `docker compose pull`.
4. Run atomic migration job: `docker compose run --rm migrate`.
5. Rollout new service containers: `docker compose up -d --wait --wait-timeout 180`.
6. Execute HTTP smoke check against the ingress proxy. On failure, invoke `rollback.sh` immediately.
7. Persist active digests to `/var/lib/deploy/previous.env`.

### `rollback.sh`
1. Load `/var/lib/deploy/previous.env` and redeploy prior digests via `docker compose up -d --wait`.
2. Never rollback database schemas destructively; database migrations must remain forward and backward compatible (expand-and-contract pattern) so older application code executes safely against the current schema.