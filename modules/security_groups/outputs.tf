output "workstation_sg_id"   { value = aws_security_group.workstation.id }
output "control_plane_sg_id" { value = aws_security_group.control_plane.id }
output "data_plane_sg_id"    { value = aws_security_group.data_plane.id }