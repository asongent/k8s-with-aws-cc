output "vpc_id" {
  value = aws_vpc.newgen_network.id
}

output "igw_id" {
  value       = aws_internet_gateway.igw.id
}
