output "control_plane_subnet_id" { value = aws_subnet.control_plane.id }
output "data_plane_subnet_id"    { value = aws_subnet.data_plane.id }
output "workstation_subnet_id"   { value = aws_subnet.workstation.id }