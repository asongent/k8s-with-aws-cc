resource "aws_vpc" "newgen_network" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = var.vpc_name
    "kubernetes.io/role/internal-elb"        = "1"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.newgen_network.id

  tags = {
    Name = "newgen-stack-igw"
   "kubernetes.io/cluster/kubernetes"       = "owned"
  }
}