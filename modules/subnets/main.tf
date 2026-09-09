# Subnets
resource "aws_subnet" "control_plane" {
  vpc_id                  = var.vpc_id
  cidr_block              = var.control_plane_cidr
  map_public_ip_on_launch = false
  tags = { 
    "kubernetes.io/role/internal-elb"        = "1"
    "kubernetes.io/cluster/kubernetes"       = "owned"
     Name = var.control_plane_subnet_name                           }
}

resource "aws_subnet" "data_plane" {
  vpc_id                  = var.vpc_id
  cidr_block              = var.data_plane_cidr
  map_public_ip_on_launch = false
  tags                    = { Name = var.data_plane_subnet_name }
}

resource "aws_subnet" "workstation" {
  vpc_id                  = var.vpc_id
  cidr_block              = var.workstation_cidr
  map_public_ip_on_launch = true
  tags = { 
    Name = var.workstation_subnet_name 
    "kubernetes.io/role/internal-elb"        = "1"
    "kubernetes.io/cluster/kubernetes"       = "owned"
    }
}

# NAT Gateway & Elastic IP
resource "aws_eip" "nat_eip" {
  domain = "vpc"
  tags   = { Name = "pubic-nat-eip" }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.workstation.id
  tags          = { Name = "pubic-nat" }
}

# Route Tables
resource "aws_route_table" "control_plane" {
  vpc_id = var.vpc_id
  tags   = { Name = "controle-plane"}
}

resource "aws_route_table" "data_plane" {
  vpc_id = var.vpc_id
  tags   = { Name = "data-plane" }
}

resource "aws_route_table" "workstation" {
  vpc_id = var.vpc_id
  tags   = { Name = "workstation" }
}
# NAT Routes for Public  Subnets
resource "aws_route" "ws_nat_route" {
  route_table_id         = aws_route_table.workstation.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = var.internet_gateway_id
}

# NAT Routes for Private Subnets
resource "aws_route" "cp_nat_route" {
  route_table_id         = aws_route_table.control_plane.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}

resource "aws_route" "dp_nat_route" {
  route_table_id         = aws_route_table.data_plane.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}

# Route Associations
resource "aws_route_table_association" "cp" {
  subnet_id      = aws_subnet.control_plane.id
  route_table_id = aws_route_table.control_plane.id
}

resource "aws_route_table_association" "dp" {
  subnet_id      = aws_subnet.data_plane.id
  route_table_id = aws_route_table.data_plane.id
}

resource "aws_route_table_association" "ws" {
  subnet_id      = aws_subnet.workstation.id
  route_table_id = aws_route_table.workstation.id
}