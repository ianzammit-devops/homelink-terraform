# Create a data block to get the availability zones for our region to use for the subnets
data "aws_availability_zones" "available" {
  state = "available"
}

# Create main VPC
resource "aws_vpc" "main" {
  cidr_block       = var.vpc_cidr_block
  instance_tenancy = "default"

  tags = {
    Name = "Terraform-Managed-VPC-${var.environment}"
  }
}

# VPC Flow Logs (to CloudWatch)
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/flow-logs/${var.environment}"
  retention_in_days = 30
}

resource "aws_iam_role" "vpc_flow_logs" {
  name = "vpc-flow-logs-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRole"
      Principal = {
        Service = "vpc-flow-logs.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "vpc_flow_logs" {
  name = "vpc-flow-logs-policy-${var.environment}"
  role = aws_iam_role.vpc_flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Resource = aws_cloudwatch_log_group.vpc_flow_logs.arn
    }]
  })
}

resource "aws_flow_log" "vpc" {
  vpc_id               = aws_vpc.main.id
  traffic_type         = "ALL"
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.vpc_flow_logs.arn
  iam_role_arn         = aws_iam_role.vpc_flow_logs.arn
}

# Create the subnets from the foreach map
resource "aws_subnet" "subnets" {
  for_each = var.subnets

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value
  availability_zone = data.aws_availability_zones.available.names[index(keys(var.subnets), each.key)]

  tags = {
    Name = "Terraform-Managed-Subnet-${each.key}"
  }
}


# We now want to create our Internet Gateway and attach it to our VPC
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "Public-Private-Terraform-IGW-${var.environment}"
  }
}

# Create route table for the IGW with destination 0.0.0.0/0 and target the IGW
# This sends any traffic not destined for the VPC out through the IGW
# There is already a default route for local traffic so we don't need to add it here
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "Public-Route-Table-Terraform-${var.environment}"
  }
}

# Associate the route table with the public subnet as the private will NOT have internet connectivity
resource "aws_route_table_association" "public_route_table_association" {
  subnet_id      = aws_subnet.subnets["public"].id
  route_table_id = aws_route_table.public.id
}

# Next steps in nacls.tf
# Next steps in ec2.tf
# Next steps in rds.tf