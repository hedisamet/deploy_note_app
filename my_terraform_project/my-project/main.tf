# Declare the VPC resource
resource "aws_vpc" "tp_cloud_devops_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "tp_cloud_devops_vpc"
  }
}

# Create a public subnet
resource "aws_subnet" "public_subnet_1" {
  vpc_id     = aws_vpc.tp_cloud_devops_vpc.id
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone = "us-east-1a"

  tags = {
    Name = "public-subnet-1"
  }
}

# Create an Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.tp_cloud_devops_vpc.id

  tags = {
    Name = "main-igw"
  }
}

# Create a route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.tp_cloud_devops_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "public-rt"
  }
}

# Associate the route table with the public subnet
resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public.id
}




# Generate an SSH key pair
resource "tls_private_key" "example_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "deployer_key" {
  key_name   = var.ssh_key_name
  public_key = tls_private_key.example_ssh_key.public_key_openssh
}

# S3 object to store the private key
resource "aws_s3_object" "private_key_object" {
  bucket       = "custom-terraform-state-bucket-123456-dc5ea108"
  key          = "${var.ssh_key_name}.pem"
  content      = tls_private_key.example_ssh_key.private_key_pem
  acl          = "private"
  server_side_encryption = "AES256"
}


# Security group
resource "aws_security_group" "web_sg" {
  name        = "web-server-sg"
  vpc_id      = aws_vpc.tp_cloud_devops_vpc.id
  description = "Security group for web server and SSH access"
}

# Allow inbound HTTP traffic on port 8080
resource "aws_security_group_rule" "allow_web_http_inbound" {
  type              = "ingress"
  security_group_id = aws_security_group.web_sg.id
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

# Allow inbound HTTP traffic on port 80
resource "aws_security_group_rule" "allow_web_http_inbound-80" {
  type              = "ingress"
  security_group_id = aws_security_group.web_sg.id
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

# Allow inbound SSH traffic on port 22
resource "aws_security_group_rule" "allow_web_ssh_inbound" {
  type              = "ingress"
  security_group_id = aws_security_group.web_sg.id
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

# Allow all outbound traffic
resource "aws_security_group_rule" "allow_all_outbound" {
  type              = "egress"
  security_group_id = aws_security_group.web_sg.id
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

# Launch an EC2 instance in the public subnet
resource "aws_instance" "public_instance" {
  ami                    = var.ec2_ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public_subnet_1.id
  key_name               = aws_key_pair.deployer_key.key_name
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  
  user_data = <<-EOF
    #!/bin/bash
    echo "<h1>Hello, World</h1>" > index.html
    # Start a simple HTTP server on port 8080
    python3 -m http.server 8080 &
  EOF

  tags = {
    Name = "PublicInstance"
  }
}

terraform {
  # Comment this out for initial setup
  
  backend "s3" {
    bucket         = "custom-terraform-state-bucket-123456-dc5ea108"
    key            = "aws-backend/main/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "custom-terraform-state-locks"
    encrypt        = true
 }
  
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id            = aws_vpc.tp_cloud_devops_vpc.id
  cidr_block        = var.public_subnet_2_cidr
  map_public_ip_on_launch = true
  availability_zone = var.availability_zone_2

  tags = {
    Name = "public-subnet-2"
  }
}


resource "aws_db_subnet_group" "mydb_subnet_group" {
  name       = "mydb_subnet_group"
  subnet_ids = [
    aws_subnet.public_subnet_1.id,
    aws_subnet.public_subnet_2.id
  ]

  tags = {
    Name = "mydb_subnet_group"
  }
}


# Create an RDS MySQL database instance
resource "aws_db_instance" "mydb" {
  allocated_storage = 20 # Minimum storage size for MySQL
  engine = "mysql"
  engine_version = "8.0.35" # Specify the MySQL engine version
  instance_class = "db.t3.micro" # Free-tier eligible instance type
  identifier = "mydb"
  username = "dbuser" # Master username
  password = "DBpassword2024" # Master password
  db_subnet_group_name = aws_db_subnet_group.mydb_subnet_group.name
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  publicly_accessible = true # Restrict public access
  multi_az = false # Single-AZ deployment
  skip_final_snapshot = true # Skip snapshot on deletion
  tags = {
  Name = "enis_tp"
  }
}
# Allow inbound RDS traffic (e.g., MySQL on port 3306)
resource "aws_security_group_rule" "allow_rds_inbound" {
  type = "ingress"
  security_group_id = aws_security_group.web_sg.id
  from_port = 3306 
  to_port = 3306 
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"] 
}
# Allow inbound to backend on port 8000
  resource "aws_security_group_rule" "allow_backend_inbound" {
  type = "ingress"
  security_group_id = aws_security_group.web_sg.id
  from_port = 8000
  to_port = 8000 # Same as above
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"] 
}
# Allow inbound HTTP traffic on port 81 to access the final application
  resource "aws_security_group_rule" "allow_web_http_inbound-81" {
  type = "ingress"
  security_group_id = aws_security_group.web_sg.id
  from_port = 81
  to_port = 81
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}