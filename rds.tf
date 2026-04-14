# Fetch the db username and password from the secrets manager
data "aws_secretsmanager_secret_version" "db" {
  secret_id = var.db_secret_name
}

# Set local variables for the db username and password that we will use later on
locals {
  db_creds = jsondecode(data.aws_secretsmanager_secret_version.db.secret_string)
}

# Apply the same NACL rules to the private RDS subnet as we did to the private subnet
resource "aws_network_acl_association" "private_rds" {
  network_acl_id = aws_network_acl.private.id
  subnet_id      = aws_subnet.subnets["private_rds"].id
}

# Group the private and private RDS subnets together for RDS
resource "aws_db_subnet_group" "default" {
  name       = "main-subnet-group-terraform-${var.environment}"
  subnet_ids = [aws_subnet.subnets["private_rds"].id, aws_subnet.subnets["private_rds_redundancy"].id]

  tags = {
    Name = "RDS-Subnet-Group-Terraform"
  }
}

# Create a security group for the RDS instance to allow inbound traffic from the EC2 instance
resource "aws_security_group" "rds_sg" {
  name        = "rds-security-group-terraform-${var.environment}"
  description = "Allow inbound traffic from the EC2 instance"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow inbound traffic from the EC2 instance"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.subnets["public"].cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "RDS-Security-Group-Terraform-${var.environment}"
  }
}

# MySQL 8.0 RDS; creds from Secrets Manager
resource "aws_db_instance" "default" {
  identifier                      = "terraform-db-instance-${var.environment}"
  allocated_storage               = 20
  db_name                         = var.db_name
  engine                          = "mysql"
  engine_version                  = "8.0"
  instance_class                  = "db.t3.micro"
  username                        = local.db_creds.username
  password                        = local.db_creds.password
  parameter_group_name            = "default.mysql8.0"
  skip_final_snapshot             = true
  db_subnet_group_name            = aws_db_subnet_group.default.name
  publicly_accessible             = false
  vpc_security_group_ids          = [aws_security_group.rds_sg.id]
  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]
}