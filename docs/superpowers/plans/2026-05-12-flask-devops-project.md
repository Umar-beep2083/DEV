# Flask DevOps Portfolio Project — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a production-ready two-tier Flask + MySQL Task Manager REST API with Docker, CI/CD via GitHub Actions, and AWS ECR/ECS deployment.

**Architecture:** Application factory pattern — `extensions.py` holds the SQLAlchemy singleton, `models.py` and `routes.py` import from it, `app.py` defines `create_app()` only. A separate `wsgi.py` calls `create_app()` as the gunicorn entry point — this keeps the module-level MySQL call out of the import path used by tests. Tests use SQLite in-memory (no MySQL required in CI).

**Tech Stack:** Python 3.11, Flask 3.0, Flask-SQLAlchemy 3.1, PyMySQL 1.1, gunicorn 21.2, MySQL 8.0, Docker (multi-stage), Docker Compose, GitHub Actions, AWS ECR + ECS Fargate (us-east-1, account 105927215341)

---

## File Map

| File | Purpose |
|------|---------|
| `app/extensions.py` | `db = SQLAlchemy()` singleton — imported by models and app |
| `app/models.py` | `Task` SQLAlchemy model + `TaskStatus` enum |
| `app/routes.py` | Flask Blueprint — all 6 REST endpoints |
| `app/app.py` | `create_app()` factory only — no module-level app creation |
| `app/wsgi.py` | gunicorn entry point: `from app import create_app; app = create_app()` |
| `app/tests/conftest.py` | pytest fixtures: creates test client with SQLite in-memory |
| `app/tests/test_app.py` | 5 endpoint tests |
| `docker/Dockerfile` | Multi-stage build (builder + runtime) |
| `docker/mysql/init.sql` | Schema DDL + 3 sample rows |
| `docker-compose.yml` | Local dev: flask-app + mysql-db with healthcheck |
| `docker-compose.prod.yml` | Prod-style: no exposed MySQL port, restart:always |
| `.github/workflows/deploy.yml` | CI/CD: test → build+push ECR → deploy ECS |
| `scripts/deploy.sh` | Manual AWS deployment helper |
| `scripts/health-check.sh` | Post-deploy health poll |
| `.env.example` | Environment variable template |
| `.gitignore` | Ignores .env, __pycache__, logs, etc. |
| `README.md` | Full portfolio-quality docs |

---

## Task 1: Project Scaffold

**Files:**
- Create: `app/extensions.py` (empty placeholder — filled in Task 2)
- Create: `app/requirements.txt`
- Create: `.env.example`
- Create: `.gitignore`
- Create: `app/tests/__init__.py` (empty)

- [ ] **Step 1: Create the directory tree**

```powershell
$base = "c:\Users\Umari\OneDrive\Desktop\Academics\Projects\DEV\flask-devops-project"
New-Item -ItemType Directory -Force "$base\app\tests"
New-Item -ItemType Directory -Force "$base\docker\mysql"
New-Item -ItemType Directory -Force "$base\scripts"
New-Item -ItemType Directory -Force "$base\.github\workflows"
```

- [ ] **Step 2: Write `app/requirements.txt`**

```
Flask==3.0.0
Flask-SQLAlchemy==3.1.1
PyMySQL==1.1.0
python-dotenv==1.0.0
gunicorn==21.2.0
cryptography==41.0.7
```

- [ ] **Step 3: Write `.env.example`**

```bash
# Database
DB_NAME=taskdb
DB_USER=flaskuser
DB_PASSWORD=flaskpassword
MYSQL_ROOT_PASSWORD=rootpassword

# Flask
FLASK_ENV=development
SECRET_KEY=your-secret-key-here-change-in-production

# AWS (for manual deployment)
AWS_REGION=us-east-1
ECR_REGISTRY=105927215341.dkr.ecr.us-east-1.amazonaws.com
ECR_REPOSITORY=flask-devops-app
ECS_CLUSTER=flask-devops-cluster
ECS_SERVICE=flask-devops-service
```

- [ ] **Step 4: Write `.gitignore`**

```
.env
__pycache__/
*.pyc
*.pyo
.pytest_cache/
*.egg-info/
dist/
.DS_Store
*.log
mysql_data/
.venv/
venv/
```

- [ ] **Step 5: Create empty `app/tests/__init__.py`**

Create an empty file at `app/tests/__init__.py`.

- [ ] **Step 6: Commit**

```bash
git add app/requirements.txt .env.example .gitignore app/tests/__init__.py
git commit -m "chore: project scaffold — requirements, env template, gitignore"
```

---

## Task 2: SQLAlchemy Extension

**Files:**
- Create: `app/extensions.py`

- [ ] **Step 1: Write `app/extensions.py`**

```python
from flask_sqlalchemy import SQLAlchemy

db = SQLAlchemy()
```

- [ ] **Step 2: Commit**

```bash
git add app/extensions.py
git commit -m "feat: add SQLAlchemy db singleton"
```

---

## Task 3: Task Model

**Files:**
- Create: `app/models.py`

- [ ] **Step 1: Write `app/models.py`**

```python
import enum
from datetime import datetime, timezone
from extensions import db


class TaskStatus(str, enum.Enum):
    pending = 'pending'
    in_progress = 'in_progress'
    completed = 'completed'


class Task(db.Model):
    __tablename__ = 'tasks'

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    title = db.Column(db.String(255), nullable=False)
    description = db.Column(db.Text, nullable=True)
    status = db.Column(
        db.Enum(TaskStatus),
        default=TaskStatus.pending,
        nullable=False
    )
    created_at = db.Column(
        db.DateTime,
        default=lambda: datetime.now(timezone.utc)
    )
    updated_at = db.Column(
        db.DateTime,
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc)
    )

    def to_dict(self):
        return {
            'id': self.id,
            'title': self.title,
            'description': self.description,
            'status': self.status.value,
            'created_at': self.created_at.isoformat(),
            'updated_at': self.updated_at.isoformat(),
        }
```

- [ ] **Step 2: Commit**

```bash
git add app/models.py
git commit -m "feat: add Task model with status enum and to_dict serializer"
```

---

## Task 4: Routes Blueprint

**Files:**
- Create: `app/routes.py`

- [ ] **Step 1: Write `app/routes.py`**

```python
from flask import Blueprint, jsonify, request
from extensions import db
from models import Task, TaskStatus

tasks_bp = Blueprint('tasks', __name__)


@tasks_bp.route('/')
def health_check():
    return jsonify({'status': 'healthy', 'app': 'Flask DevOps App'}), 200


@tasks_bp.route('/health')
def health_detailed():
    db_status = 'connected'
    try:
        db.session.execute(db.text('SELECT 1'))
    except Exception as e:
        db_status = f'error: {str(e)}'
    return jsonify({
        'status': 'healthy',
        'app': 'Flask DevOps App',
        'database': db_status,
    }), 200


@tasks_bp.route('/tasks', methods=['GET'])
def get_tasks():
    tasks = Task.query.all()
    return jsonify([t.to_dict() for t in tasks]), 200


@tasks_bp.route('/tasks', methods=['POST'])
def create_task():
    data = request.get_json()
    if not data or not data.get('title'):
        return jsonify({'error': 'title is required'}), 400
    status_val = data.get('status', 'pending')
    try:
        status = TaskStatus(status_val)
    except ValueError:
        return jsonify({'error': f'invalid status: {status_val}'}), 400
    task = Task(
        title=data['title'],
        description=data.get('description'),
        status=status,
    )
    db.session.add(task)
    db.session.commit()
    return jsonify(task.to_dict()), 201


@tasks_bp.route('/tasks/<int:task_id>', methods=['PUT'])
def update_task(task_id):
    task = Task.query.get(task_id)
    if not task:
        return jsonify({'error': 'task not found'}), 404
    data = request.get_json()
    if not data:
        return jsonify({'error': 'request body required'}), 400
    if 'title' in data:
        task.title = data['title']
    if 'description' in data:
        task.description = data['description']
    if 'status' in data:
        try:
            task.status = TaskStatus(data['status'])
        except ValueError:
            return jsonify({'error': f'invalid status: {data["status"]}'}), 400
    db.session.commit()
    return jsonify(task.to_dict()), 200


@tasks_bp.route('/tasks/<int:task_id>', methods=['DELETE'])
def delete_task(task_id):
    task = Task.query.get(task_id)
    if not task:
        return jsonify({'error': 'task not found'}), 404
    db.session.delete(task)
    db.session.commit()
    return jsonify({'message': f'task {task_id} deleted'}), 200
```

- [ ] **Step 2: Commit**

```bash
git add app/routes.py
git commit -m "feat: add routes blueprint with 6 REST endpoints"
```

---

## Task 5: Application Factory + Entry Point

**Files:**
- Create: `app/app.py`
- Create: `app/wsgi.py`

- [ ] **Step 1: Write `app/app.py`**

```python
import os
from flask import Flask
from extensions import db
from models import Task  # noqa: F401 — registers model with SQLAlchemy metadata
from routes import tasks_bp


def create_app(config=None):
    flask_app = Flask(__name__)

    flask_app.config.update({
        'SQLALCHEMY_DATABASE_URI': (
            'mysql+pymysql://{user}:{pw}@{host}:{port}/{name}'.format(
                user=os.environ.get('DB_USER', 'flaskuser'),
                pw=os.environ.get('DB_PASSWORD', 'flaskpassword'),
                host=os.environ.get('DB_HOST', 'localhost'),
                port=os.environ.get('DB_PORT', '3306'),
                name=os.environ.get('DB_NAME', 'taskdb'),
            )
        ),
        'SQLALCHEMY_TRACK_MODIFICATIONS': False,
        'SECRET_KEY': os.environ.get('SECRET_KEY', 'dev-key-change-in-prod'),
    })

    if config:
        flask_app.config.update(config)

    db.init_app(flask_app)
    flask_app.register_blueprint(tasks_bp)

    with flask_app.app_context():
        db.create_all()

    return flask_app
```

- [ ] **Step 2: Write `app/wsgi.py`**

```python
from app import create_app

app = create_app()
```

This file is the gunicorn entry point. Keeping it separate means importing `app.py` in tests never triggers a MySQL connection — `create_app()` is only called here (by gunicorn) and in the test fixtures (with SQLite config).

- [ ] **Step 3: Commit**

```bash
git add app/app.py app/wsgi.py
git commit -m "feat: add application factory and wsgi entry point"
```

---

## Task 6: Test Suite

**Files:**
- Create: `app/tests/conftest.py`
- Create: `app/tests/test_app.py`

- [ ] **Step 1: Write `app/tests/conftest.py`**

```python
import sys
import os
import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from app import create_app
from extensions import db as _db


@pytest.fixture
def app():
    test_app = create_app({
        'TESTING': True,
        'SQLALCHEMY_DATABASE_URI': 'sqlite:///:memory:',
    })
    with test_app.app_context():
        _db.create_all()
        yield test_app
        _db.drop_all()


@pytest.fixture
def client(app):
    return app.test_client()
```

- [ ] **Step 2: Write `app/tests/test_app.py`**

```python
import json


def test_health_check(client):
    response = client.get('/')
    assert response.status_code == 200
    data = json.loads(response.data)
    assert data['status'] == 'healthy'
    assert data['app'] == 'Flask DevOps App'


def test_health_detailed(client):
    response = client.get('/health')
    assert response.status_code == 200
    data = json.loads(response.data)
    assert 'database' in data


def test_get_tasks_returns_list(client):
    response = client.get('/tasks')
    assert response.status_code == 200
    data = json.loads(response.data)
    assert isinstance(data, list)


def test_create_task(client):
    payload = {'title': 'Test task', 'description': 'A test description'}
    response = client.post(
        '/tasks',
        data=json.dumps(payload),
        content_type='application/json',
    )
    assert response.status_code == 201
    data = json.loads(response.data)
    assert data['id'] is not None
    assert data['title'] == 'Test task'
    assert data['status'] == 'pending'


def test_update_and_delete_task(client):
    # Create
    response = client.post(
        '/tasks',
        data=json.dumps({'title': 'To update'}),
        content_type='application/json',
    )
    task_id = json.loads(response.data)['id']

    # Update
    response = client.put(
        f'/tasks/{task_id}',
        data=json.dumps({'status': 'completed'}),
        content_type='application/json',
    )
    assert response.status_code == 200
    assert json.loads(response.data)['status'] == 'completed'

    # Delete
    response = client.delete(f'/tasks/{task_id}')
    assert response.status_code == 200

    # Verify gone
    response = client.delete(f'/tasks/{task_id}')
    assert response.status_code == 404
```

- [ ] **Step 3: Install dependencies and run tests**

```bash
cd app
pip install -r requirements.txt pytest
python -m pytest tests/ -v
```

Expected output:
```
tests/test_app.py::test_health_check PASSED
tests/test_app.py::test_health_detailed PASSED
tests/test_app.py::test_get_tasks_returns_list PASSED
tests/test_app.py::test_create_task PASSED
tests/test_app.py::test_update_and_delete_task PASSED

5 passed in <2s
```

- [ ] **Step 4: Commit**

```bash
git add app/tests/conftest.py app/tests/test_app.py
git commit -m "test: add pytest suite with SQLite in-memory fixtures"
```

---

## Task 7: Multi-Stage Dockerfile

**Files:**
- Create: `docker/Dockerfile`

- [ ] **Step 1: Write `docker/Dockerfile`**

```dockerfile
# ── Stage 1: Builder ───────────────────────────────────────────────────────────
FROM python:3.11-slim AS builder

WORKDIR /build

COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ── Stage 2: Runtime ───────────────────────────────────────────────────────────
FROM python:3.11-slim AS runtime

WORKDIR /app

COPY --from=builder /install/lib /usr/local/lib
COPY --from=builder /install/bin /usr/local/bin

RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app
USER appuser

COPY --chown=appuser:appuser . .

EXPOSE 5000

CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "wsgi:app"]
```

- [ ] **Step 2: Verify the image builds (requires Docker running)**

Run from the `flask-devops-project/` root:

```bash
docker build -t flask-devops-test --target runtime -f docker/Dockerfile ./app
```

Expected: `Successfully built <id>` with no errors. If Docker is not available locally, skip this step — CI will catch build failures.

- [ ] **Step 3: Commit**

```bash
git add docker/Dockerfile
git commit -m "feat: add multi-stage Dockerfile (builder + runtime, non-root user)"
```

---

## Task 8: MySQL Init + Docker Compose

**Files:**
- Create: `docker/mysql/init.sql`
- Create: `docker-compose.yml`
- Create: `docker-compose.prod.yml`

- [ ] **Step 1: Write `docker/mysql/init.sql`**

```sql
CREATE DATABASE IF NOT EXISTS taskdb;
USE taskdb;

CREATE TABLE IF NOT EXISTS tasks (
    id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    status ENUM('pending', 'in_progress', 'completed') DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

INSERT INTO tasks (title, description, status) VALUES
('Set up Docker environment', 'Configure Docker and Docker Compose for the project', 'completed'),
('Deploy to AWS ECS', 'Push Docker image to ECR and deploy to ECS Fargate', 'in_progress'),
('Write documentation', 'Write complete README and API documentation', 'pending');
```

- [ ] **Step 2: Write `docker-compose.yml`**

```yaml
version: '3.8'

services:
  flask-app:
    build:
      context: ./app
      dockerfile: ../docker/Dockerfile
    container_name: flask_app
    ports:
      - "5000:5000"
    environment:
      - DB_HOST=mysql-db
      - DB_PORT=3306
      - DB_NAME=${DB_NAME:-taskdb}
      - DB_USER=${DB_USER:-flaskuser}
      - DB_PASSWORD=${DB_PASSWORD:-flaskpassword}
      - FLASK_ENV=development
    depends_on:
      mysql-db:
        condition: service_healthy
    networks:
      - app-network
    restart: unless-stopped

  mysql-db:
    image: mysql:8.0
    container_name: mysql_db
    ports:
      - "3306:3306"
    environment:
      - MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD:-rootpassword}
      - MYSQL_DATABASE=${DB_NAME:-taskdb}
      - MYSQL_USER=${DB_USER:-flaskuser}
      - MYSQL_PASSWORD=${DB_PASSWORD:-flaskpassword}
    volumes:
      - mysql_data:/var/lib/mysql
      - ./docker/mysql/init.sql:/docker-entrypoint-initdb.d/init.sql
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      timeout: 10s
      retries: 10
      interval: 5s
    networks:
      - app-network
    restart: unless-stopped

networks:
  app-network:
    driver: bridge

volumes:
  mysql_data:
    driver: local
```

- [ ] **Step 3: Write `docker-compose.prod.yml`**

```yaml
version: '3.8'

services:
  flask-app:
    image: ${ECR_REGISTRY:-105927215341.dkr.ecr.us-east-1.amazonaws.com}/flask-devops-app:${IMAGE_TAG:-latest}
    container_name: flask_app_prod
    ports:
      - "5000:5000"
    environment:
      - DB_HOST=mysql-db
      - DB_PORT=3306
      - DB_NAME=${DB_NAME:-taskdb}
      - DB_USER=${DB_USER:-flaskuser}
      - DB_PASSWORD=${DB_PASSWORD:-flaskpassword}
      - FLASK_ENV=production
    depends_on:
      mysql-db:
        condition: service_healthy
    networks:
      - app-network
    restart: always

  mysql-db:
    image: mysql:8.0
    container_name: mysql_db_prod
    environment:
      - MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD:-rootpassword}
      - MYSQL_DATABASE=${DB_NAME:-taskdb}
      - MYSQL_USER=${DB_USER:-flaskuser}
      - MYSQL_PASSWORD=${DB_PASSWORD:-flaskpassword}
    volumes:
      - mysql_data_prod:/var/lib/mysql
      - ./docker/mysql/init.sql:/docker-entrypoint-initdb.d/init.sql
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      timeout: 10s
      retries: 10
      interval: 5s
    networks:
      - app-network
    restart: always

networks:
  app-network:
    driver: bridge

volumes:
  mysql_data_prod:
    driver: local
```

- [ ] **Step 4: Smoke-test local stack (requires Docker running)**

```bash
cp .env.example .env
docker-compose up --build -d
docker-compose ps
```

Expected: both `flask_app` and `mysql_db` show `Up` status. Then:

```bash
curl http://localhost:5000/health
# Expected: {"app":"Flask DevOps App","database":"connected","status":"healthy"}

curl http://localhost:5000/tasks
# Expected: [{"id":1,...},{"id":2,...},{"id":3,...}]
```

Then tear down:

```bash
docker-compose down
```

- [ ] **Step 5: Commit**

```bash
git add docker/mysql/init.sql docker-compose.yml docker-compose.prod.yml
git commit -m "feat: add MySQL init script and Docker Compose configs"
```

---

## Task 9: GitHub Actions CI/CD Pipeline

**Files:**
- Create: `.github/workflows/deploy.yml`

- [ ] **Step 1: Write `.github/workflows/deploy.yml`**

```yaml
name: CI/CD Pipeline - Build and Deploy to AWS ECS

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

env:
  AWS_REGION: us-east-1
  ECR_REGISTRY: 105927215341.dkr.ecr.us-east-1.amazonaws.com
  ECR_REPOSITORY: flask-devops-app
  ECS_SERVICE: flask-devops-service
  ECS_CLUSTER: flask-devops-cluster
  CONTAINER_NAME: flask-app

jobs:
  # ── Job 1: Test ───────────────────────────────────────────────────────────────
  test:
    name: Run Tests
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'

      - name: Install dependencies
        run: |
          cd app
          pip install -r requirements.txt pytest

      - name: Run tests
        run: |
          cd app
          python -m pytest tests/ -v

  # ── Job 2: Build & Push to ECR ────────────────────────────────────────────────
  build:
    name: Build and Push Docker Image
    runs-on: ubuntu-latest
    needs: test
    if: github.ref == 'refs/heads/main'
    outputs:
      image: ${{ steps.build-image.outputs.image }}

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v2

      - name: Build, tag, and push image to ECR
        id: build-image
        env:
          IMAGE_TAG: ${{ github.sha }}
        run: |
          docker build \
            --target runtime \
            -f docker/Dockerfile \
            -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG \
            ./app
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
          echo "image=$ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG" >> $GITHUB_OUTPUT

  # ── Job 3: Deploy to ECS ──────────────────────────────────────────────────────
  deploy:
    name: Deploy to AWS ECS
    runs-on: ubuntu-latest
    needs: build

    steps:
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Deploy to ECS
        run: |
          aws ecs update-service \
            --cluster ${{ env.ECS_CLUSTER }} \
            --service ${{ env.ECS_SERVICE }} \
            --force-new-deployment \
            --region ${{ env.AWS_REGION }}

      - name: Wait for deployment to complete
        run: |
          aws ecs wait services-stable \
            --cluster ${{ env.ECS_CLUSTER }} \
            --services ${{ env.ECS_SERVICE }} \
            --region ${{ env.AWS_REGION }}

      - name: Deployment success
        run: echo "Deployment complete!"
```

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/deploy.yml
git commit -m "ci: add GitHub Actions pipeline — test, build to ECR, deploy to ECS"
```

---

## Task 10: Deployment Scripts

**Files:**
- Create: `scripts/deploy.sh`
- Create: `scripts/health-check.sh`

- [ ] **Step 1: Write `scripts/deploy.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

AWS_REGION="us-east-1"
AWS_ACCOUNT_ID="105927215341"
ECR_REPOSITORY="flask-devops-app"
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
IMAGE_TAG="${1:-latest}"

echo "Logging into ECR..."
aws ecr get-login-password --region "$AWS_REGION" | \
  docker login --username AWS --password-stdin "$ECR_REGISTRY"

echo "Building Docker image (tag: $IMAGE_TAG)..."
docker build \
  --target runtime \
  -f docker/Dockerfile \
  -t "$ECR_REPOSITORY:$IMAGE_TAG" \
  ./app

echo "Tagging for ECR..."
docker tag "$ECR_REPOSITORY:$IMAGE_TAG" "$ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG"

echo "Pushing to ECR..."
docker push "$ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG"

echo "Deploying to ECS..."
aws ecs update-service \
  --cluster flask-devops-cluster \
  --service flask-devops-service \
  --force-new-deployment \
  --region "$AWS_REGION"

echo "Waiting for deployment to stabilise..."
aws ecs wait services-stable \
  --cluster flask-devops-cluster \
  --services flask-devops-service \
  --region "$AWS_REGION"

echo "Done. Image: $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG"
```

- [ ] **Step 2: Write `scripts/health-check.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

HOST="${1:-localhost}"
PORT="${2:-5000}"
URL="http://${HOST}:${PORT}"
MAX_RETRIES=10
RETRY_INTERVAL=5

echo "Health check: ${URL}/health"

for i in $(seq 1 "$MAX_RETRIES"); do
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${URL}/health" || true)

  if [ "$HTTP_STATUS" = "200" ]; then
    echo "PASS (attempt $i)"
    curl -s "${URL}/health" | python3 -m json.tool
    exit 0
  fi

  echo "Attempt $i/$MAX_RETRIES — status $HTTP_STATUS. Retrying in ${RETRY_INTERVAL}s..."
  sleep "$RETRY_INTERVAL"
done

echo "FAIL — health check did not pass after $MAX_RETRIES attempts"
exit 1
```

- [ ] **Step 3: Make scripts executable (on Linux/Mac or in WSL)**

```bash
chmod +x scripts/deploy.sh scripts/health-check.sh
```

On Windows the executable bit is set via git:
```bash
git add scripts/deploy.sh scripts/health-check.sh
git update-index --chmod=+x scripts/deploy.sh scripts/health-check.sh
git commit -m "feat: add deploy and health-check scripts"
```

---

## Task 11: README

**Files:**
- Create: `README.md`

- [ ] **Step 1: Write `README.md`**

````markdown
# Flask DevOps App

![CI/CD Pipeline](https://github.com/Umar-beep2083/DEV/actions/workflows/deploy.yml/badge.svg)

A production-ready two-tier Task Manager REST API built to demonstrate real-world DevOps practices: containerization, multi-container orchestration, CI/CD automation, and cloud deployment on AWS.

**Author:** Umar — Fresh Graduate | DevOps Engineer  
AWS Certified Cloud Practitioner | AWS Security Specialty

---

## Architecture

```
┌─────────────────────────────────────────────────┐
│              GitHub Repository                   │
│  (push to main) → GitHub Actions CI/CD Pipeline │
└──────────────────────┬──────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────┐
│                  AWS Cloud                       │
│                                                  │
│  AWS ECR ◄── docker build + push                │
│      │                                           │
│      ▼                                           │
│  AWS ECS Fargate                                 │
│  ┌─────────────┐     ┌─────────────┐            │
│  │  Flask App  │◄───►│  MySQL DB   │            │
│  │  Container  │     │  Container  │            │
│  └─────────────┘     └─────────────┘            │
│         │                                        │
│  Application Load Balancer (public)              │
└─────────────────────────────────────────────────┘
```

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Backend | Python 3.11, Flask 3.0 |
| Database | MySQL 8.0 |
| Containerization | Docker (multi-stage build) |
| Orchestration | Docker Compose |
| CI/CD | GitHub Actions |
| Cloud Registry | AWS ECR |
| Cloud Deployment | AWS ECS Fargate |
| Region | us-east-1 |

---

## Quick Start (Local)

**Prerequisites:** Docker, Docker Compose, Git

```bash
# 1. Clone
git clone https://github.com/Umar-beep2083/DEV.git
cd DEV/flask-devops-project

# 2. Set environment variables
cp .env.example .env

# 3. Start all containers
docker-compose up --build -d

# 4. Verify
docker-compose ps
curl http://localhost:5000/health
```

---

## API Reference

| Method | Endpoint | Description | Body |
|--------|----------|-------------|------|
| GET | `/` | Health check | — |
| GET | `/health` | Health + DB status | — |
| GET | `/tasks` | List all tasks | — |
| POST | `/tasks` | Create task | `{"title": "...", "description": "...", "status": "pending"}` |
| PUT | `/tasks/<id>` | Update task | `{"title": "...", "status": "completed"}` |
| DELETE | `/tasks/<id>` | Delete task | — |

**Status values:** `pending` · `in_progress` · `completed`

### curl Examples

```bash
# Health check
curl http://localhost:5000/health

# List tasks
curl http://localhost:5000/tasks

# Create a task
curl -X POST http://localhost:5000/tasks \
  -H "Content-Type: application/json" \
  -d '{"title": "My task", "description": "Details here"}'

# Update a task
curl -X PUT http://localhost:5000/tasks/1 \
  -H "Content-Type: application/json" \
  -d '{"status": "completed"}'

# Delete a task
curl -X DELETE http://localhost:5000/tasks/1
```

---

## Running Tests

```bash
cd app
pip install -r requirements.txt pytest
python -m pytest tests/ -v
```

---

## AWS Deployment

### Prerequisites
- AWS CLI configured (`aws configure`)
- Permissions: ECR, ECS, IAM

### 1. Create ECR Repository

```bash
aws ecr create-repository \
  --repository-name flask-devops-app \
  --region us-east-1
```

### 2. Build & Push Image Manually

```bash
chmod +x scripts/deploy.sh
./scripts/deploy.sh latest
```

### 3. Create ECS Cluster

```bash
aws ecs create-cluster --cluster-name flask-devops-cluster
```

### 4. Register Task Definition + Create ECS Service

Use the AWS Console (ECS → Task Definitions → Create new) with:
- Container name: `flask-app`
- Image: `105927215341.dkr.ecr.us-east-1.amazonaws.com/flask-devops-app:latest`
- Port: `5000`
- Environment variables: `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`

Then create a Fargate service pointing to the task definition with an Application Load Balancer.

---

## CI/CD: GitHub Actions Secrets

Go to: **GitHub repo → Settings → Secrets → Actions → New repository secret**

| Secret | Description |
|--------|-------------|
| `AWS_ACCESS_KEY_ID` | IAM user access key with ECR + ECS permissions |
| `AWS_SECRET_ACCESS_KEY` | IAM user secret key |

The pipeline runs automatically on every push to `main`.

---

## Project Structure

```
flask-devops-project/
├── app/
│   ├── app.py               # Application factory + gunicorn entry point
│   ├── extensions.py        # SQLAlchemy db singleton
│   ├── models.py            # Task model
│   ├── routes.py            # REST API Blueprint
│   ├── requirements.txt
│   └── tests/
│       ├── conftest.py      # SQLite in-memory test fixtures
│       └── test_app.py      # 5 endpoint tests
├── docker/
│   ├── Dockerfile           # Multi-stage build
│   └── mysql/init.sql       # Schema + sample data
├── docker-compose.yml       # Local development
├── docker-compose.prod.yml  # Production reference
├── .github/workflows/
│   └── deploy.yml           # CI/CD pipeline
├── scripts/
│   ├── deploy.sh            # Manual deployment
│   └── health-check.sh      # Post-deploy verification
└── README.md
```

---

## Future Enhancements

- **Terraform** — Infrastructure as Code for VPC, ECS, RDS
- **AWS RDS** — Replace containerized MySQL with managed RDS instance
- **CloudWatch** — Metrics, alarms, log groups
- **Auto-scaling** — ECS service scaling policies
- **HTTPS** — AWS Certificate Manager + ALB listener
- **Redis** — Caching layer for task queries
````

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add full portfolio-quality README with architecture, API ref, and AWS guide"
```

---

## Task 12: Git Init and Push to GitHub

- [ ] **Step 1: Initialize git repo (if not already done)**

```bash
git init
git branch -M main
```

- [ ] **Step 2: Add remote**

```bash
git remote add origin https://github.com/Umar-beep2083/DEV.git
```

- [ ] **Step 3: Stage all uncommitted files**

```bash
git add .
git status
```

Review the output — confirm `.env` is NOT listed (it should be gitignored). If it appears, remove it: `git rm --cached .env`

- [ ] **Step 4: Push**

```bash
git push -u origin main
```

- [ ] **Step 5: Verify the pipeline triggers**

Go to `https://github.com/Umar-beep2083/DEV/actions` and confirm the CI/CD workflow appears and the `test` job runs green. The `build` and `deploy` jobs will only fully succeed once the ECS cluster/service exist in AWS.

---

## Success Checklist

- [ ] `cd app && python -m pytest tests/ -v` — 5 passed
- [ ] `docker-compose up --build -d` — both containers healthy
- [ ] `curl http://localhost:5000/health` — `{"database":"connected",...}`
- [ ] `curl http://localhost:5000/tasks` — returns 3 sample tasks
- [ ] Push to `main` triggers GitHub Actions — `test` job passes
- [ ] `build` job pushes image to `105927215341.dkr.ecr.us-east-1.amazonaws.com/flask-devops-app:<sha>`
- [ ] `deploy` job calls `aws ecs update-service` successfully
