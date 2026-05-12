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
│   ├── app.py               # Application factory
│   ├── extensions.py        # SQLAlchemy db singleton
│   ├── models.py            # Task model
│   ├── routes.py            # REST API Blueprint
│   ├── wsgi.py              # gunicorn entry point
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
