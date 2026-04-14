# NACL Public setup
resource "aws_network_acl" "main" {
  vpc_id = aws_vpc.main.id

  ingress {
    protocol   = "6"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  ingress {
    protocol   = "6"
    rule_no    = 110
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  ingress {
    protocol   = "6"
    rule_no    = 120
    action     = "allow"
    cidr_block = var.my_ip_address

    from_port = 22
    to_port   = 22
  }

  ingress {
    protocol   = "17"
    rule_no    = 130
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  egress {
    protocol   = "6"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  egress {
    protocol   = "6"
    rule_no    = 110
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  egress {
    protocol   = "6"
    rule_no    = 120
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  egress {
    protocol   = "17"
    rule_no    = 130
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 53
    to_port    = 53
  }

  egress {
    protocol   = "6"
    rule_no    = 140
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 53
    to_port    = 53
  }


  # Allow outbound traffic to the database which will be located in the private subnet
  egress {
    protocol   = "6"
    rule_no    = 150
    action     = "allow"
    cidr_block = aws_subnet.subnets["private_rds"].cidr_block
    from_port  = 3306
    to_port    = 3306
  }

  tags = {
    Name = "Public-NACL-Terraform-${var.environment}"
  }
}

# Associate the NACL with the public subnet
resource "aws_network_acl_association" "main" {
  network_acl_id = aws_network_acl.main.id
  subnet_id      = aws_subnet.subnets["public"].id
}

# We need to create NACL's for the private subnet and associate them with the private subnet
resource "aws_network_acl" "private" {
  vpc_id = aws_vpc.main.id

  ingress {
    protocol   = "6"
    rule_no    = 110
    action     = "allow"
    cidr_block = aws_subnet.subnets["public"].cidr_block
    from_port  = 3306
    to_port    = 3306
  }

  ingress {
    protocol   = "6"
    rule_no    = 100
    action     = "allow"
    cidr_block = aws_subnet.subnets["public"].cidr_block
    from_port  = 1024
    to_port    = 65535
  }

  # Only allow out empemnermal ports to the public subnet
  egress {
    protocol   = "6"
    rule_no    = 100
    action     = "allow"
    cidr_block = aws_subnet.subnets["public"].cidr_block
    from_port  = 1024
    to_port    = 65535
  }
}

# Second RDS subnet: same private NACL as private_rds (associated in rds.tf)
resource "aws_network_acl_association" "private_rds_redundancy" {
  network_acl_id = aws_network_acl.private.id
  subnet_id      = aws_subnet.subnets["private_rds_redundancy"].id
}