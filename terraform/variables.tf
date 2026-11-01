variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "eu-central-1"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "team262-app"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "prod"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key file for EC2 access"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to connect via SSH (restrict to your IP/32 in production)"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Note: Must allow GitHub Actions runners if deploying via SSH without self-hosted runner
}

variable "root_volume_size" {
  description = "Size of the root EBS volume in GB (keep at 20GB to leave 10GB of Free Tier for Monitoring VM)"
  type        = number
  default     = 20
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private RDS subnets across two Availability Zones"
  type        = list(string)
  default     = ["10.0.2.0/24", "10.0.3.0/24"]
}

variable "mysql_database" {
  description = "Name of the MySQL database (maps to MYSQL_DATABASE in Spring Boot)"
  type        = string
  default     = "moviematch"
}

variable "mysql_user" {
  description = "Master username for RDS MySQL (maps to MYSQL_USER in Spring Boot)"
  type        = string
  default     = "moviematch_admin"
}

variable "mysql_password" {
  description = "Master password for RDS MySQL (injected via TF_VAR_mysql_password)"
  type        = string
  sensitive   = true
}