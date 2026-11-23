variable "workstation_subnet_id" {}
variable "control_plane_subnet_id" {}
variable "data_plane_subnet_id" {}
variable "workstation_sg_id" {}
variable "control_plane_sg_id" {}
variable "data_plane_sg_id" {}
variable "instance_profile_name" {}
variable "key_pair" {}
variable "workstation_instance_type" {}
variable "control_plane_instance_type" {}
variable "data_plan_instance_type" {}
# variable "ssh_user" {}
variable "private_key_path" {
}
variable "control_plane_count" {
  description = "Number of Kubernetes control plane nodes (use 1 for dev, 3 for HA)"
  type        = number
  default     = 1
}

variable "data_plane_count" {
  description = "Number of Kubernetes data plane nodes"
  type        = number
  default     = 1
}
