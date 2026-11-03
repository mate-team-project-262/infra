# 1. Dynamic AMI Lookup (Ubuntu 22.04 LTS Jammy)
data "aws_ami" "ubuntu_22_04" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Fetch available Availability Zones in the current region
data "aws_availability_zones" "available" {
  state = "available"
}

# 2. Networking (VPC, Subnet, IGW, Route Table)
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# 3. Security Group (Firewall Rules: 22, 80, 443)
resource "aws_security_group" "web_sg" {
  name        = "${var.project_name}-sg"
  description = "Allow SSH, HTTP, and HTTPS inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidr
  }

  ingress {
    description = "HTTP access for Nginx"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS access for Nginx"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic (for OS updates and pulling Docker images)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-sg"
  }
}

# 4. Compute (SSH Key Pair & EC2 Instance)
resource "aws_key_pair" "deployer" {
  key_name   = "${var.project_name}-key"
  public_key = file(pathexpand(var.ssh_public_key_path))
}

resource "aws_instance" "app_server" {
  ami                    = data.aws_ami.ubuntu_22_04.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  key_name               = aws_key_pair.deployer.key_name

  # Pass bootstrap script and trigger replacement if script changes
  user_data                   = file("${path.module}/../scripts/bootstrap.sh")
  user_data_replace_on_change = true

  # Enforce IMDSv2 for enhanced instance metadata security
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  # Encrypted GP3 root volume (20GB is within the 30GB Free Tier limit)
  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name = "${var.project_name}-ec2"
  }
}

# Allocate a static Elastic IP (association is handled below by aws_eip_association)
resource "aws_eip" "app_eip" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-eip"
  }
}

# Bind the Elastic IP to the EC2 instance
resource "aws_eip_association" "eip_assoc" {
  instance_id   = aws_instance.app_server.id
  allocation_id = aws_eip.app_eip.id
}

# 5. Database Layer (Private Subnets, Security Group, Parameter Group & RDS)

# Create 2 private subnets across different AZs (required for RDS Subnet Group)
resource "aws_subnet" "private" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project_name}-private-subnet-${count.index + 1}"
  }
}

resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "${var.project_name}-rds-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "${var.project_name}-rds-subnet-group"
  }
}

# Allow port 3306 strictly from the EC2 application server Security Group
resource "aws_security_group" "rds_sg" {
  name        = "${var.project_name}-rds-sg"
  description = "Allow MySQL inbound traffic strictly from EC2 web_sg"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "MySQL access from EC2 instance only"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }

  tags = {
    Name = "${var.project_name}-rds-sg"
  }
}

# Replicate docker-compose character-set and collation settings in AWS RDS (MySQL 8.4 LTS)
resource "aws_db_parameter_group" "mysql_utf8mb4" {
  name        = "${var.project_name}-mysql84-utf8mb4"
  family      = "mysql8.4"
  description = "Enforce utf8mb4 character set and unicode collation for TMDB movie data"

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "collation_server"
    value = "utf8mb4_unicode_ci"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# AWS RDS MySQL 8.4 LTS Instance (Standard Support - no Extended Support charges)
resource "aws_db_instance" "mysql" {
  identifier        = "${var.project_name}-db"
  engine            = "mysql"
  engine_version    = "8.4"
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.mysql_database
  username = var.mysql_user
  password = var.mysql_password

  parameter_group_name   = aws_db_parameter_group.mysql_utf8mb4.name
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  # Strictly private and Single-AZ to avoid extra AWS charges
  publicly_accessible = false
  multi_az            = false

  # Allow immediate in-place upgrade from 8.0 to 8.4 LTS
  allow_major_version_upgrade = true
  apply_immediately           = true

  # Automated daily backups
  backup_retention_period = 1
  backup_window           = "03:00-04:00"
  maintenance_window      = "Sun:04:00-Sun:05:00"

  skip_final_snapshot = true
  deletion_protection = false

  tags = {
    Name = "${var.project_name}-rds"
  }
}