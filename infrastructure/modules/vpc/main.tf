data "aws_availability_zones" "available" {
  # Filter only AZs that support g5.xlarge
  filter {
    name   = "zone-name"
    values = ["ca-central-1a", "ca-central-1b"]
  }
}

locals {
  vpc_cidrs = {
    dev  = "10.1.0.0/16"
    prod = "10.2.0.0/16"
  }
}

resource "aws_vpc" "main" {
  cidr_block           = local.vpc_cidrs[terraform.workspace]
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { 
    Name = "geniuspod-vpc-${terraform.workspace}"
    Environment = terraform.workspace
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { 
    Name = "geniuspod-igw-${terraform.workspace}"
    Environment = terraform.workspace
  }
}

resource "aws_eip" "nat" {
  tags = { 
    Name = "geniuspod-nat-eip-${terraform.workspace}"
    Environment = terraform.workspace
  }
}

resource "aws_subnet" "public" {
  count                   = length(data.aws_availability_zones.available.names)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(local.vpc_cidrs[terraform.workspace], 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name = "geniuspod-public-${terraform.workspace}-${data.aws_availability_zones.available.names[count.index]}"
    Environment = terraform.workspace
  }
}

resource "aws_subnet" "private" {
  count             = length(data.aws_availability_zones.available.names)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(local.vpc_cidrs[terraform.workspace], 8, count.index + 10)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "geniuspod-private-${terraform.workspace}-${data.aws_availability_zones.available.names[count.index]}"
    Environment = terraform.workspace
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  tags          = { 
    Name = "geniuspod-nat-${terraform.workspace}"
    Environment = terraform.workspace
  }
  depends_on    = [aws_internet_gateway.igw]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { 
    Name = "geniuspod-public-rt-${terraform.workspace}"
    Environment = terraform.workspace
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = { 
    Name = "geniuspod-private-rt-${terraform.workspace}"
    Environment = terraform.workspace
  }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]
  tags              = { 
    Name = "geniuspod-s3-endpoint-${terraform.workspace}"
    Environment = terraform.workspace
  }
}