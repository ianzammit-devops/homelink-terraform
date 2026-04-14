# Create the EC2 Instance and link this with the VPC and the public subnet
# First we will create a security group so we can attach to the EC2 Instance
resource "aws_security_group" "web_server_sg" {
  name        = "web-server-security-group-${var.environment}"
  description = "Apache/PHP on 80; SSH permitted only from my IP"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_address]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Web-Server-Security-Group-${var.environment}"
  }
}

# Public IP required for demo purposes - in production a load balancer would be used instead
resource "aws_instance" "web_server" { # nosemgrep: terraform.aws.security.aws-ec2-has-public-ip.aws-ec2-has-public-ip
  depends_on = [aws_db_instance.default]

  ami                         = var.ec2_ami
  instance_type               = var.ec2_instance_type
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.subnets["public"].id
  security_groups             = [aws_security_group.web_server_sg.id]
  key_name                    = "terraform-public-private-${var.environment}"
  iam_instance_profile        = var.ec2_iam_instance_profile

  user_data = templatefile("${path.module}/user-data.tpl", {
    db_host                  = aws_db_instance.default.address
    db_name                  = aws_db_instance.default.db_name
    db_secret_name           = var.db_secret_name
    github_token_secret_name = var.github_deploy_token_secret_name
  })

  metadata_options {
    http_tokens = "required"
  }

  tags = {
    Name = "Apache-PHP-Web-Server-Terraform-${var.environment}"
  }
}
