data "aws_ami" "ubuntu_2404" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

# Workstation
# Workstation
resource "aws_instance" "workstation" {
  ami                         = data.aws_ami.ubuntu_2404.id
  key_name                    = var.key_pair
  instance_type               = "t3.medium"
  subnet_id                   = var.workstation_subnet_id
  vpc_security_group_ids      = [var.workstation_sg_id]
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              set -e

              # 1. Install kubectl via snap
              apt-get update -y
              apt install ansible-core -y
              snap install kubectl --classic

              # 2. Add kubecolor PPA/repository and install
              apt-get update -y
              apt-get install -y software-properties-common
              apt-get install kubecolor -y

              # 3. Add alias k=kubecolor to ubuntu and root user .bashrc
              for USER_HOME in /home/ubuntu /root; do
                if [ -d "$USER_HOME" ]; then
                  echo 'alias k=kubecolor' >> "$USER_HOME/.bashrc"
                  echo 'complete -o default -F __start_kubectl k' >> "$USER_HOME/.bashrc"
                  chown $(stat -c '%U:%G' "$USER_HOME") "$USER_HOME/.bashrc"
                fi
              done
              EOF

  user_data_replace_on_change = true

  tags = { Name = "workstation" }

  # Create ~/.ssh on the remote server
  provisioner "remote-exec" {
    inline = [
      "mkdir -p ~/.ssh",
      "chmod 700 ~/.ssh"
    ]

    connection {
      type        = "ssh"
      host        = self.public_ip
      user        = "ubuntu"
      private_key = file(var.private_key_path)
    }
  }

  # Copy local .ssh/newgen.pem to remote ~/.ssh/newgen.pem
  provisioner "file" {
    source      = "~/.ssh/newgen.pem"
    destination = "/home/ubuntu/.ssh/newgen.pem"

    connection {
      type        = "ssh"
      host        = self.public_ip
      user        = "ubuntu"
      private_key = file(var.private_key_path)
    }
  }

  # Restrict permissions on the private key
  provisioner "remote-exec" {
    inline = [
      "chmod 400 ~/.ssh/newgen.pem"
    ]

    connection {
      type        = "ssh"
      host        = self.public_ip
      user        = "ubuntu"
      private_key = file(var.private_key_path)
    }
  }
}


# Control Plane
resource "aws_instance" "control_plane" {
  ami                         = data.aws_ami.ubuntu_2404.id
  instance_type               = "t3.medium"
  key_name                    = var.key_pair       
  subnet_id                   = var.control_plane_subnet_id
  vpc_security_group_ids      = [var.control_plane_sg_id]
  associate_public_ip_address = false
  iam_instance_profile        = var.instance_profile_name

  tags = { 
    Name = "control-plane" 
    "kubernetes.io/cluster/kubernetes"       = "owned"
    }
}

# Data Plane Nodes
resource "aws_instance" "nodes" {
  for_each                    = toset(["node-01", "node-02", "node-03", "node-04"])
  ami                         = data.aws_ami.ubuntu_2404.id
  key_name                    = var.key_pair
  instance_type               = "t3.medium"
  subnet_id                   = var.data_plane_subnet_id
  vpc_security_group_ids      = [var.data_plane_sg_id]
  associate_public_ip_address = false
  iam_instance_profile        = var.instance_profile_name
  tags   = { 
    Name = each.key
    "kubernetes.io/role/internal-elb"        = "1"
    "kubernetes.io/cluster/kubernetes"       = "owned"
   }
}