# VPC Output
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "internet_gateway_id" {
  value = module.vpc.igw_id
}

# Subnet Outputs
output "subnet_ids" {
  description = "Map of all Subnet IDs"
  value = {
    control_plane = module.subnets.control_plane_subnet_id
    data_plane    = module.subnets.data_plane_subnet_id
    workstation   = module.subnets.workstation_subnet_id
  }
}

# Security Group Outputs
output "security_group_ids" {
  description = "Map of all Security Group IDs"
  value = {
    workstation   = module.security_groups.workstation_sg_id
    control_plane = module.security_groups.control_plane_sg_id
    data_plane    = module.security_groups.data_plane_sg_id
  }
}

# IAM Output
output "instance_profile_name" {
  description = "The name/ID of the IAM Instance Profile"
  value       = module.iam.instance_profile_name
}

# Server Outputs (IP Addresses)
output "server_ips" {
  description = "IP addresses of all provisioned servers"
  value = {
    workstation = {
      public_ip  = module.servers.workstation_public_ip
      private_ip = module.servers.workstation_private_ip
    }
    control_plane = {
      private_ip = module.servers.control_plane_private_ip
    }
    worker_nodes = module.servers.worker_nodes_private_ips
  }
}