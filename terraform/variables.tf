variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "owner" {
  description = "Owner tag value, used as prefix for resource names"
  type        = string
  default     = "bravosix"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Name of the existing EC2 key pair for SSH access"
  type        = string
  default = "cpt"
}

# ============================================================
# SENSITIVE — provide via terraform.tfvars (gitignored)
# or TF_VAR_* environment variables
# ============================================================

variable "db_root_password" {
  description = "MySQL root password"
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "MySQL database name"
  type        = string
  default     = "bookstore_db"
}

variable "db_user" {
  description = "MySQL application user"
  type        = string
  default     = "bookstore_user"
}

variable "db_password" {
  description = "MySQL application user password"
  type        = string
  sensitive   = true
}
