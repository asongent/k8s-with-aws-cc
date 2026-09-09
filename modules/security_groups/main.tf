# Workstation SG
resource "aws_security_group" "workstation" {
  name        = var.workstation_sg_name
  description = "Workstation security group"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "workstation" }
}

# Control-Plane SG
resource "aws_security_group" "control_plane" {
  name        = var.control_plane_sg_name
  description = "Kubernetes Control Plane Security Group"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = [
      { port = 6443, desc = "Kubernetes API Server" },
      { port = 2379, desc = "etcd client API" },
      { port = 2380, desc = "etcd client API" },
      { port = 10250, desc = "Kubelet API" },
      { port = 10259, desc = "kube-scheduler" },
      { port = 10257, desc = "kube-controller-manager" },
      { port = 22, desc = "SSH" },
      { port = 179, desc = "calico network" }
    ]
    content {
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = "tcp"
      cidr_blocks = ["192.168.0.0/16"]
      description = ingress.value.desc
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "control_plane" }
}

# Data-Plane SG
resource "aws_security_group" "data_plane" {
  name        = var.data_plane_sg_name
  description = "Kubernetes Worker Nodes Security Group"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = [
      { from = 10250, to = 10250, desc = "Kubelet API" },
      { from = 30000, to = 32767, desc = "NodePort Services" },
      { from = 179, to = 179, desc = "calico" },
      { from = 6443, to = 6443, desc = "api server communication" },
      { from = 22, to = 22, desc = "SSH" }
    ]
    content {
      from_port   = ingress.value.from
      to_port     = ingress.value.to
      protocol    = "tcp"
      cidr_blocks = ["192.168.0.0/16"]
      description = ingress.value.desc
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "data-plane" }
}

# Allow all internal communication within and between cluster security groups
resource "aws_security_group_rule" "control_plane_from_data_plane" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.control_plane.id
  source_security_group_id = aws_security_group.data_plane.id
  description              = "Allow all ingress traffic from worker nodes"
}

resource "aws_security_group_rule" "data_plane_from_control_plane" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.data_plane.id
  source_security_group_id = aws_security_group.control_plane.id
  description              = "Allow all ingress traffic from control plane"
}

resource "aws_security_group_rule" "data_plane_self" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.data_plane.id
  self                     = true
  description              = "Allow intra-worker communication"
}

# # OpenVPN Access Server Security Group
# resource "aws_security_group" "openvpn" {
#   name        = var.openvpn_sg_name
#   description = "OpenVPN Access Server Security Group"
#   vpc_id      = var.vpc_id

#   # OpenVPN Client Tunnel (UDP 1194)
#   ingress {
#     from_port   = 1194
#     to_port     = 1194
#     protocol    = "udp"
#     cidr_blocks = ["0.0.0.0/0"]
#     description = "OpenVPN UDP tunnel traffic"
#   }

#   # OpenVPN Admin & Client Web Portals (TCP 443 / 943)
#   ingress {
#     from_port   = 443
#     to_port     = 443
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#     description = "OpenVPN Client Web UI / HTTPS"
#   }

#   ingress {
#     from_port   = 943
#     to_port     = 943
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#     description = "OpenVPN Admin Web UI"
#   }

#   # SSH Access
#   ingress {
#     from_port   = 22
#     to_port     = 22
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#     description = "SSH access"
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#     description = "Allow all outbound traffic to VPC and Internet"
#   }

#   tags = { Name = "openvpn-sg" }
# }

# # Allow OpenVPN clients full access to Control Plane nodes
# resource "aws_security_group_rule" "control_plane_from_openvpn" {
#   type                     = "ingress"
#   from_port                = 0
#   to_port                  = 0
#   protocol                 = "-1"
#   security_group_id        = aws_security_group.control_plane.id
#   source_security_group_id = aws_security_group.openvpn.id
#   description              = "Allow traffic from OpenVPN server"
# }

# # Allow OpenVPN clients full access to Worker nodes & NodePort services
# resource "aws_security_group_rule" "data_plane_from_openvpn" {
#   type                     = "ingress"
#   from_port                = 0
#   to_port                  = 0
#   protocol                 = "-1"
#   security_group_id        = aws_security_group.data_plane.id
#   source_security_group_id = aws_security_group.openvpn.id
#   description              = "Allow traffic from OpenVPN server"
# }
