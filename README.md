# 📚 Bookstore API — Dockerized Flask Application on AWS

A production-ready, containerized REST API for bookstore management, deployed on AWS EC2 using Docker Compose and provisioned with Terraform Infrastructure as Code.

---

## 🏗️ Architecture

```
Internet → EC2 Instance (Security Group)
                └── Docker Network (bravosixnet)
                        ├── Flask App Container  (:80)
                        └── MySQL 8.0 Container  (internal only)
                                └── Named Volume (bravosixvol)
```

**Infrastructure provisioned via Terraform:**
- EC2 instance (Amazon Linux 2, kernel 5.10)
- Security Group with dynamic port rules
- AMI fetched dynamically via AWS SSM Parameter Store (no hardcoded IDs)
- Encrypted gp3 root volume

---

## 🛠️ Tech Stack

| Layer | Technology |
|-------|-----------|
| Language | Python 3.11 |
| Framework | Flask 2.3 |
| Database | MySQL 8.0 |
| Containerization | Docker + Docker Compose v2 |
| IaC | Terraform ~> 5.0 |
| Cloud | AWS EC2, SSM |

---

## 📁 Project Structure

```
.
├── Dockerfile                  # Multi-stage build, non-root user
├── docker-compose.yml          # Service orchestration, healthchecks
├── requirements.txt            # Pinned Python dependencies
├── bookstore-api.py            # Flask application
├── main.tf                     # Terraform resources
├── variables.tf                # Input variable definitions
├── terraform.tfvars.example    # Variable template (copy → terraform.tfvars)
├── .env.example                # Secrets template (copy → .env)
├── .gitignore                  # Excludes secrets, state files, caches
└── README.md
```

---

## 🚀 Quick Start

### Prerequisites
- Docker & Docker Compose v2
- Terraform >= 1.5.0
- AWS CLI configured (`aws configure`)
- An existing EC2 Key Pair

### 1. Run Locally with Docker Compose

```bash
# Clone the repository
git clone https://github.com/your-username/bookstore-docker-project.git
cd bookstore-docker-project

# Set up environment variables
cp .env.example .env
# Edit .env with your values
nano .env

# Build and start containers
docker-compose up -d

# Verify containers are healthy
docker-compose ps

# View logs
docker-compose logs -f
```

App will be available at `http://localhost:80`

### 2. Deploy to AWS with Terraform

```bash
# Set up Terraform variables
cp terraform.tfvars.example terraform.tfvars
# Edit with your values (this file is gitignored)
nano terraform.tfvars

# Initialize Terraform
terraform init

# Preview infrastructure changes
terraform plan

# Deploy
terraform apply

# Get the app URL from output
terraform output app_url
```

### Destroy Infrastructure

```bash
terraform destroy
```

---

## 🔒 Security Practices

- **No secrets in source code** — all credentials via `.env` / `terraform.tfvars` (both gitignored)
- **Non-root Docker user** — app runs as `appuser`, not root
- **Multi-stage Docker build** — build tools absent from runtime image
- **`no-new-privileges` security option** — containers cannot escalate privileges
- **Encrypted EBS volume** — root block device uses AES-256 encryption
- **Sensitive Terraform variables** — marked `sensitive = true`, never appear in logs
- **Dynamic AMI lookup** — SSM Parameter Store, no hardcoded AMI IDs
- **MySQL not exposed** — database port is internal to Docker network only
- **Healthchecks** — both app and database containers have healthchecks; app waits for DB to be healthy before starting

---

## 📡 API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/` | Health check |
| GET | `/books` | List all books |
| GET | `/books/<id>` | Get book by ID |
| POST | `/books` | Add a new book |
| PUT | `/books/<id>` | Update a book |
| DELETE | `/books/<id>` | Delete a book |

---

## 🔧 Environment Variables

Copy `.env.example` to `.env` and fill in values:

| Variable | Description |
|----------|-------------|
| `MYSQL_ROOT_PASSWORD` | MySQL root password |
| `MYSQL_DATABASE` | Database name |
| `MYSQL_USER` | App database user |
| `MYSQL_PASSWORD` | App database password |
| `FLASK_ENV` | `production` or `development` |
| `SECRET_KEY` | Flask session secret (min 32 chars) |

---

## 📝 License

MIT
