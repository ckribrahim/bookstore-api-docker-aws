# 📚 Bookstore API — Dockerized Flask Application on AWS

A production-ready, containerized REST API deployed on AWS EC2 using Docker Compose, provisioned with Terraform IaC. Secrets are managed via AWS SSM Parameter Store — no credentials ever touch source code or Terraform state.

---

## 🏗️ Architecture

```
Internet
    │
    ▼
EC2 Instance (Security Group: 80, 443, 22)
    │   IAM Role → SSM Parameter Store (secrets)
    │
    └── Docker Network (bravosixnet)
            ├── Flask App Container  (port 80)
            └── MySQL 8.0 Container  (internal only)
                    └── Named Volume (bravosixvol)
```

---

## 🛠️ Tech Stack

| Layer | Technology |
|-------|-----------|
| Language | Python 3.11 |
| Framework | Flask 2.3 |
| Database | MySQL 8.0 |
| Containerization | Docker + Docker Compose v2 |
| IaC | Terraform ~> 5.0 |
| Cloud | AWS EC2, SSM Parameter Store, IAM |

---

## 📁 Project Structure

```
.
├── app/
│   ├── bookstore-api.py        # Flask application
│   └── requirements.txt        # Pinned Python dependencies
├── docker/
│   ├── Dockerfile              # Multi-stage build, non-root user
│   └── docker-compose.yml      # Service orchestration with healthchecks
├── terraform/
│   ├── main.tf                 # All AWS resources
│   ├── variables.tf            # Input variable definitions
│   └── terraform.tfvars.example  # Variable template
├── .env.example                # Local dev secrets template
├── .gitignore
└── README.md
```

---

## 🚀 Deployment

### Prerequisites
- Terraform >= 1.5.0
- AWS CLI configured (`aws configure`)
- An existing EC2 Key Pair

### Deploy to AWS

```bash
# 1. Set up Terraform variables
cd terraform
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars   # fill in your values

# 2. Initialize and deploy
terraform init
terraform plan
terraform apply

# 3. Get app URL
terraform output app_url
```

### Destroy

```bash
terraform destroy
```

---

## 💻 Local Development

```bash
cp .env.example .env
nano .env   # fill in values

docker-compose -f docker/docker-compose.yml up -d
docker-compose -f docker/docker-compose.yml logs -f
```

---

## 🔒 Security Highlights

| Practice | Implementation |
|----------|---------------|
| No secrets in code | Credentials via SSM Parameter Store |
| No secrets in state | SSM values fetched at runtime by EC2 |
| Least privilege IAM | EC2 role can only read `bookstore/*` SSM params |
| Non-root container | App runs as `appuser`, not root |
| Multi-stage build | Build tools absent from runtime image |
| Encrypted EBS | Root volume uses gp3 + AES-256 |
| DB not exposed | MySQL port internal to Docker network only |
| Healthchecks | App waits for DB healthy before starting |

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

## 📝 License

MIT
