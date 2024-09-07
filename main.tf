terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.59.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}




# Create VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

# Create Public Subnet
resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true
}

# Create Private Subnet
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"
}
resource "aws_subnet" "private_az_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1b"
}


# Create IGW
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

# Create NAT Gateway
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id
}

# Create EIP for NAT
resource "aws_eip" "nat" {
  domain = "vpc"
}
# Create CMK Key
resource "aws_kms_key" "cmk" {
  description             = "CMK Key for EC2 and RDS"
  deletion_window_in_days = 7
}

# Create EC2 Instance in Private Subnet
resource "aws_instance" "ec2" {
  ami           = "ami-0e86e20dae9224db8"
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.ec2.id]


  # Encrypt volume with CMK Key
  root_block_device {
    encrypted = true
    kms_key_id = aws_kms_key.cmk.id
  }
}

# Create RDS in Private Subnet
resource "aws_db_instance" "rds" {
  allocated_storage    = 20
  engine               = "mysql"
  instance_class       = "db.t3.micro"
  username             = "myuser"
  password             = "mypassword"
  db_subnet_group_name = aws_db_subnet_group.rds.id
  vpc_security_group_ids = [aws_security_group.rds.id]
  kms_key_id           = aws_kms_key.cmk.arn
  storage_encrypted    = true
}

# Create DB Subnet Group
resource "aws_db_subnet_group" "rds" {
  name       = "rds-subnet-group"
  subnet_ids = [aws_subnet.private.id, aws_subnet.private_az_b.id]
}

# Create Security Groups
resource "aws_security_group" "ec2" {
  name        = "ec2-sg"
  description = "Allow inbound traffic on port 22"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "rds" {
  name        = "rds-sg"
  description = "Allow inbound traffic on port 3306"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}