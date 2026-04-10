terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ============================================================
# DATA SOURCES
# ============================================================

# Always fetch latest Amazon Linux 2 AMI — no hardcoded IDs
data "aws_ssm_parameter" "al2_ami" {
  name = "/aws/service/ami-amazon-linux-latest/amzn2-ami-kernel-5.10-hvm-x86_64-gp2"
}

# ============================================================
# LOCALS
# ============================================================

locals {
  project = "bookstore"
  owner   = var.owner

  allowed_ports = [22, 80, 443, 5000, 8080]

  common_tags = {
    Project     = local.project
    Owner       = local.owner
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ============================================================
# SSM PARAMETER STORE — secrets never touch user_data or state
# ============================================================

resource "aws_ssm_parameter" "db_root_password" {
  name        = "/${local.project}/db_root_password"
  description = "MySQL root password for ${local.project}"
  type        = "SecureString"
  value       = var.db_root_password

  tags = local.common_tags
}

resource "aws_ssm_parameter" "db_password" {
  name        = "/${local.project}/db_password"
  description = "MySQL app user password for ${local.project}"
  type        = "SecureString"
  value       = var.db_password

  tags = local.common_tags
}

resource "aws_ssm_parameter" "db_user" {
  name        = "/${local.project}/db_user"
  description = "MySQL app username for ${local.project}"
  type        = "String"
  value       = var.db_user

  tags = local.common_tags
}

resource "aws_ssm_parameter" "db_name" {
  name        = "/${local.project}/db_name"
  description = "MySQL database name for ${local.project}"
  type        = "String"
  value       = var.db_name

  tags = local.common_tags
}

# ============================================================
# IAM — EC2 role to read SSM parameters only
# ============================================================

resource "aws_iam_role" "ec2_role" {
  name        = "${local.project}-ec2-role"
  description = "EC2 role for ${local.project} SSM read access"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "ssm_read_policy" {
  name = "${local.project}-ssm-read-policy"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ssm:GetParameter",
        "ssm:GetParameters"
      ]
      # Least privilege — only this project's parameters
      Resource = "arn:aws:ssm:${var.aws_region}:*:parameter/${local.project}/*"
    }]
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${local.project}-ec2-instance-profile"
  role = aws_iam_role.ec2_role.name

  tags = local.common_tags
}

# ============================================================
# SECURITY GROUP
# ============================================================

resource "aws_security_group" "app_sg" {
  name        = "${local.owner}-${local.project}-sg"
  description = "Security group for ${local.project} application"

  dynamic "ingress" {
    for_each = local.allowed_ports
    content {
      description = "Allow port ${ingress.value}"
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.owner}-${local.project}-sg"
  })
}

# ============================================================
# EC2 INSTANCE
# ============================================================

resource "aws_instance" "app_server" {
  ami                    = data.aws_ssm_parameter.al2_ami.value
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  monitoring             = true

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    encrypted             = true
    delete_on_termination = true
  }

  user_data = <<-EOF
    #!/bin/bash
    set -euo pipefail
    exec > /var/log/user-data.log 2>&1

    echo "=== [1/5] System update ==="
    yum update -y
    yum install -y docker git aws-cli

    echo "=== [2/5] Docker setup ==="
    systemctl start docker
    systemctl enable docker
    usermod -aG docker ec2-user

    echo "=== [3/5] Docker Compose install ==="
    curl -SL "https://github.com/docker/compose/releases/download/v2.39.2/docker-compose-linux-x86_64" \
      -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose

    echo "=== [4/5] Clone repository ==="
    cd /home/ec2-user
    git clone https://github.com/ckribrahim/bookstore-api-docker-aws.git app
    cd app

    echo "=== [5/5] Fetch secrets from SSM and create .env ==="
    DB_ROOT_PASSWORD=$(aws ssm get-parameter \
      --name "/${local.project}/db_root_password" \
      --with-decryption \
      --query "Parameter.Value" \
      --output text \
      --region ${var.aws_region})

    DB_PASSWORD=$(aws ssm get-parameter \
      --name "/${local.project}/db_password" \
      --with-decryption \
      --query "Parameter.Value" \
      --output text \
      --region ${var.aws_region})

    DB_USER=$(aws ssm get-parameter \
      --name "/${local.project}/db_user" \
      --query "Parameter.Value" \
      --output text \
      --region ${var.aws_region})

    DB_NAME=$(aws ssm get-parameter \
      --name "/${local.project}/db_name" \
      --query "Parameter.Value" \
      --output text \
      --region ${var.aws_region})

    cat > /home/ec2-user/app/.env <<ENVFILE
    MYSQL_ROOT_PASSWORD=$DB_ROOT_PASSWORD
    MYSQL_DATABASE=$DB_NAME
    MYSQL_USER=$DB_USER
    MYSQL_PASSWORD=$DB_PASSWORD
    MYSQL_HOST=database
    MYSQL_PORT=3306
    ENVFILE

    # Secure the .env file
    chmod 600 /home/ec2-user/app/.env
    chown ec2-user:ec2-user /home/ec2-user/app/.env

    echo "=== Starting application ==="
    export PATH=$PATH:/usr/local/bin
    cp /home/ec2-user/app/.env /home/ec2-user/app/docker/.env
    chmod 600 /home/ec2-user/app/docker/.env
    docker-compose -f /home/ec2-user/app/docker/docker-compose.yml up -d

    echo "=== Setup complete ==="
    EOF

  tags = merge(local.common_tags, {
    Name = "${local.owner}-${local.project}-server"
  })
}

# ============================================================
# OUTPUTS
# ============================================================

output "app_url" {
  description = "Public URL of the Bookstore application"
  value       = "http://${aws_instance.app_server.public_ip}"
}

output "instance_id" {
  description = "EC2 Instance ID"
  value       = aws_instance.app_server.id
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i '${var.key_name}.pem' ec2-user@${aws_instance.app_server.public_ip}"
}
