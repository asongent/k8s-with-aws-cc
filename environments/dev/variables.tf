variable "aws_region" {
  default = ""
}
variable "vpc_name" {}
variable "vpc_cidr" {}

variable "control_plane_cidr" {}
variable "data_plane_cidr" {}
variable "workstation_cidr" {}

variable "control_plane_subnet_name" {}
variable "data_plane_subnet_name" {}
variable "workstation_subnet_name" {}


variable "key_pair" {}
variable "control_plane_sg_name" {}
variable "data_plane_sg_name" {}
variable "workstation_sg_name" {}
variable "private_key_path" {}
# variable "openvpn_sg_name" {}

# variable "internet_gateway_id" {
#   type        = string
#   description = "The ID of the Internet Gateway from the VPC module"
# }


variable "role_name" {}
variable "policy_name" {}
variable "instance_profile_name" {}
