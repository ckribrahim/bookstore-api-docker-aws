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

# Always fetch the latest Amazon Linux 2 AMI dynamically
# No more hardcoded AMI IDs that go stale
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
# SECURITY GROUP
# ============================================================

resource "aws_security_group" "app_sg" {
  name        = "${local.owner}-${local.project}-sg"
  description = "Security group for ${local.project} Docker application"

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
    description = "Allow all outbound traffic"
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

  # Enable detailed monitoring
  monitoring = true

  # Encrypt root volume
  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    encrypted             = true
    delete_on_termination = true
  }

  user_data = <<-EOF
    #!/bin/bash
    set -e  # Exit on any error
    exec > /var/log/user-data.log 2>&1  # Log everything

    echo "=== Starting setup ==="

    yum update -y
    yum install docker git -y

    systemctl start docker
    systemctl enable docker
    usermod -aG docker ec2-user

    # Install Docker Compose v2
    curl -SL "https://github.com/docker/compose/releases/download/v2.39.2/docker-compose-linux-x86_64" \
      -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose

    # Clone and run application
    cd /home/ec2-user
    git clone https://github.com/ckribrahim/bookstore-api-docker-aws.git app
    cd app

    # Create .env file from instance metadata or pass via Terraform templatefile
    # For demo: values are injected via Terraform variables
    cat > .env <<ENVFILE
    MYSQL_ROOT_PASSWORD=${var.db_root_password}
    MYSQL_DATABASE=${var.db_name}
    MYSQL_USER=${var.db_user}
    MYSQL_PASSWORD=${var.db_password}
    ENVFILE
    chmod 600 .env
    chown ec2-user:ec2-user .env

    docker-compose up -d

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

output "public_ip" {
  description = "Public IP address"
  value       = aws_instance.app_server.public_ip
}
