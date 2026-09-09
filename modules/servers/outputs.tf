output "workstation_public_ip" {
  description = "Public IP of the workstation instance"
  value       = aws_instance.workstation.public_ip
}

output "workstation_private_ip" {
  description = "Private IP of the workstation instance"
  value       = aws_instance.workstation.private_ip
}

output "control_plane_private_ip" {
  description = "Private IP of the control-plane instance"
  value       = aws_instance.control_plane.private_ip
}

output "worker_nodes_private_ips" {
  description = "Map of private IPs for all worker nodes"
  value       = { for name, instance in aws_instance.nodes : name => instance.private_ip }
}