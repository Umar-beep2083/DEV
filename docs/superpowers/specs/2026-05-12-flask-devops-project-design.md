# Flask DevOps Portfolio Project — Design Spec

**Date:** 2026-05-12  
**Author:** Umar  
**Status:** Approved

---

## 1. Purpose

A production-ready two-tier web application for a DevOps portfolio. Demonstrates containerization, multi-container orchestration, CI/CD automation, cloud registry, and cloud deployment. Built to be shown in interviews and on GitHub.

---

## 2. Repository

- **GitHub:** `github.com/Umar-beep2083/DEV`
- **Local root:** `c:\Users\Umari\OneDrive\Desktop\Academics\Projects\DEV\flask-devops-project\`

---

## 3. Tech Stack

| Layer | Technology |
|-------|-----------|
| Backend | Python 3.11, Flask 3.0 |
| Database | MySQL 8.0 (local), AWS RDS-ready |
| Containerization | Docker (multi-stage), Docker Compose |
| CI/CD | GitHub Actions |
| Cloud Registry | AWS ECR |
| Cloud Deployment | AWS ECS Fargate |
| Testing | pytest + SQLite in-memory |
| Production server | gunicorn |

---

## 4. Project Structure

```
flask-devops-project/
├── app/
│   ├── __init__.py          # create_app() factory
│   ├── app.py               # gunicorn WSGI entry point
│   ├── models.py            # Task SQLAlchemy model
│   ├── routes.py            # Blueprint — 6 REST endpoints
│   ├── requirements.txt
│   └── tests/
│       ├── conftest.py      # pytest fixture: test client + SQLite in-memory DB
│       └── test_app.py      # 5 endpoint tests
├── docker/
│   ├── Dockerfile           # Multi-stage build (builder + runtime)
│   └── mysql/
│       └── init.sql         # Schema creation + 3 sample rows
├── docker-compose.yml       # Local development orchestration
├── docker-compose.prod.yml  # Production-style compose
├── .github/
│   └── workflows/
│       └── deploy.yml       # CI/CD: test → build+push ECR → deploy ECS
├── scripts/
│   ├── deploy.sh            # Manual AWS deployment helper
│   └── health-check.sh      # Post-deploy health verification
├── .env.example
├── .gitignore
└── README.md                # Full production-quality docs
```

---

## 5. Flask Application Design (Factory Pattern)

### 5.1 `__init__.py` — Application Factory

```
create_app(config=None):
  - Reads DB config from environment variables (DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD)
  - Falls back to SQLite in-memory when TESTING=True (enables CI without MySQL)
  - Initializes SQLAlchemy, creates all tables
  - Registers routes Blueprint
  - Returns app instance
```

### 5.2 `models.py` — Task Model

| Field | Type | Constraints |
|-------|------|-------------|
| id | Integer | Primary key, auto-increment |
| title | String(255) | NOT NULL |
| description | Text | Nullable |
| status | Enum | pending / in_progress / completed, default: pending |
| created_at | DateTime | Auto, server default |
| updated_at | DateTime | Auto, updates on row change |

### 5.3 `routes.py` — API Blueprint

| Method | Endpoint | Description | Success Code |
|--------|----------|-------------|--------------|
| GET | `/` | Health check — `{"status":"healthy","app":"Flask DevOps App"}` | 200 |
| GET | `/health` | Detailed check including DB ping | 200 |
| GET | `/tasks` | List all tasks | 200 |
| POST | `/tasks` | Create task (`title` required, `description`+`status` optional) | 201 |
| PUT | `/tasks/<id>` | Update any task field | 200 |
| DELETE | `/tasks/<id>` | Delete task by ID | 200 |

Error responses: `{"error": "<message>"}` with appropriate 4xx codes.

### 5.4 `app.py`

Calls `create_app()`, exposes `app` for gunicorn: `gunicorn --bind 0.0.0.0:5000 --workers 2 app:app`

---

## 6. Dockerfile (Multi-Stage)

```
Stage 1 — builder (python:3.11-slim):
  - Install: gcc, default-libmysqlclient-dev, pkg-config
  - pip install -r requirements.txt --target /install

Stage 2 — runtime (python:3.11-slim):
  - Copy /install from builder (no build tools in final image)
  - Add non-root user (appuser)
  - COPY app source
  - EXPOSE 5000
  - CMD gunicorn
```

Result: ~30% smaller image vs single-stage, no build tools in production.

---

## 7. Docker Compose

### `docker-compose.yml` (local dev)

- **flask-app**: builds from `docker/Dockerfile`, port 5000:5000, env vars from `.env`, `depends_on` mysql-db with `condition: service_healthy`
- **mysql-db**: `mysql:8.0`, port 3306:3306, healthcheck (`mysqladmin ping`), mounts `init.sql`
- Shared `app-network` bridge, named volume `mysql_data`

### `docker-compose.prod.yml`

- No host port exposure for MySQL (internal only)
- `restart: always`
- No build context (uses pre-built ECR image)
- Intended for reference / local prod simulation

---

## 8. MySQL Init Script (`docker/mysql/init.sql`)

- Creates `taskdb` database
- Creates `tasks` table matching the model schema
- Inserts 3 sample rows (completed / in_progress / pending) so the API returns data immediately on first run

---

## 9. Tests

### Strategy: SQLite in-memory

`conftest.py` sets `TESTING=True` and `SQLALCHEMY_DATABASE_URI="sqlite:///:memory:"`. `create_app()` detects `TESTING=True` and uses SQLite. Tables created fresh per test session, torn down after. No MySQL required in CI.

### Test Coverage (`test_app.py`)

| Test | Endpoint | Assertion |
|------|----------|-----------|
| `test_health_check` | GET `/` | status 200, `status == "healthy"` |
| `test_health_detailed` | GET `/health` | status 200, `database` key present |
| `test_get_tasks_empty` | GET `/tasks` | status 200, returns list |
| `test_create_task` | POST `/tasks` | status 201, `id` in response |
| `test_update_delete_task` | PUT + DELETE `/tasks/1` | 200 each |

---

## 10. CI/CD Pipeline (`.github/workflows/deploy.yml`)

### Job 1: `test` (all pushes + PRs to main)

```
checkout → setup-python 3.11 → pip install -r requirements.txt + pytest
→ pytest app/tests/ -v
```

### Job 2: `build` (main branch only, needs: test)

```
checkout
→ configure-aws-credentials (secrets: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)
→ amazon-ecr-login
→ docker build --target runtime (multi-stage) -t $ECR_REGISTRY/$ECR_REPO:$SHA ./app
→ docker push
→ output: image URI
```

ECR image: `105927215341.dkr.ecr.us-east-1.amazonaws.com/flask-devops-app:<git-sha>`

### Job 3: `deploy` (needs: build)

```
configure-aws-credentials
→ aws ecs update-service --cluster flask-devops-cluster --service flask-devops-service --force-new-deployment
→ aws ecs wait services-stable
→ echo deployment complete
```

### Required GitHub Secrets

| Secret | Value |
|--------|-------|
| `AWS_ACCESS_KEY_ID` | IAM user access key |
| `AWS_SECRET_ACCESS_KEY` | IAM user secret key |

---

## 11. AWS Configuration

| Resource | Name/Value |
|----------|-----------|
| Account ID | `105927215341` |
| Region | `us-east-1` |
| ECR Registry | `105927215341.dkr.ecr.us-east-1.amazonaws.com` |
| ECR Repository | `flask-devops-app` |
| ECS Cluster | `flask-devops-cluster` |
| ECS Service | `flask-devops-service` |
| Container Name | `flask-app` |

---

## 12. Environment Variables

```bash
# App
DB_HOST=mysql-db
DB_PORT=3306
DB_NAME=taskdb
DB_USER=flaskuser
DB_PASSWORD=flaskpassword
MYSQL_ROOT_PASSWORD=rootpassword
FLASK_ENV=development
SECRET_KEY=your-secret-key-here

# AWS (for manual deploy scripts)
AWS_REGION=us-east-1
ECR_REPOSITORY=flask-devops-app
ECS_CLUSTER=flask-devops-cluster
ECS_SERVICE=flask-devops-service
```

---

## 13. README Contents

1. Project overview + architecture ASCII diagram
2. Tech stack table
3. Local setup (copy .env, docker-compose up --build)
4. API endpoint reference table with curl examples
5. AWS deployment step-by-step
6. GitHub Actions secrets setup
7. GitHub Actions badge
8. Future enhancements section (Terraform, CloudWatch, RDS, auto-scaling)

---

## 14. Out of Scope

- Terraform / IaC (listed as future enhancement)
- CloudWatch alarms / monitoring
- SSL / HTTPS
- Redis caching
- AWS RDS (using containerized MySQL for local; ECS task will need env vars pointed at RDS for true prod)
- Frontend UI

---

## 15. Success Criteria

- [ ] `docker-compose up --build` starts both containers cleanly
- [ ] All 6 API endpoints return correct responses
- [ ] `pytest` passes all 5 tests
- [ ] GitHub Actions pipeline runs green on push to main
- [ ] Docker image builds successfully and pushes to ECR
- [ ] ECS service deploys new image on push to main
