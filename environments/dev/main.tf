terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

module "vpc" {
  source   = "../../modules/vpc"
  vpc_name = var.vpc_name
  vpc_cidr = var.vpc_cidr

}

module "subnets" {
  source                    = "../../modules/subnets"
  vpc_id                    = module.vpc.vpc_id
  internet_gateway_id       = module.vpc.igw_id
  control_plane_cidr        = var.control_plane_cidr
  data_plane_cidr           = var.data_plane_cidr
  workstation_cidr          = var.workstation_cidr
  control_plane_subnet_name = var.control_plane_sg_name
  data_plane_subnet_name    = var.data_plane_subnet_name
  workstation_subnet_name   = var.workstation_subnet_name
  depends_on                = [module.vpc]
}

module "security_groups" {
  source                = "../../modules/security_groups"
  vpc_id                = module.vpc.vpc_id
  control_plane_sg_name = var.control_plane_sg_name
  data_plane_sg_name    = var.data_plane_sg_name
  workstation_sg_name   = var.workstation_sg_name
  depends_on            = [module.vpc]
}

module "iam" {
  source                = "../../modules/iam"
  role_name             = var.role_name
  policy_name           = var.policy_name
  instance_profile_name = var.instance_profile_name
}

module "servers" {
  source                  = "../../modules/servers"
  key_pair                = var.key_pair
  workstation_subnet_id   = module.subnets.workstation_subnet_id
  control_plane_subnet_id = module.subnets.control_plane_subnet_id
  data_plane_subnet_id    = module.subnets.data_plane_subnet_id
  workstation_sg_id       = module.security_groups.workstation_sg_id
  control_plane_sg_id     = module.security_groups.control_plane_sg_id
  data_plane_sg_id        = module.security_groups.data_plane_sg_id
  instance_profile_name   = module.iam.instance_profile_name
  depends_on              = [module.iam, module.subnets, module.security_groups]
  private_key_path        = var.private_key_path
}