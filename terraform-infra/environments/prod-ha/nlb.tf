# 1. Create an Internal (or Internet-Facing) Network Load Balancer
resource "aws_lb" "k8s_api" {
  count                            = var.control_plane_count > 1 ? 1 : 0
  name                             = "k8s-api-nlb"
  internal                         = true
  load_balancer_type               = "network"
  subnets                          = [module.subnets.control_plane_subnet_id]
  enable_cross_zone_load_balancing = true
}


# 2. Target Group for Kubernetes API Server (TCP 6443)
resource "aws_lb_target_group" "k8s_api" {
  count              = var.control_plane_count > 1 ? 1 : 0
  name               = "k8s-api-tg"
  port               = 6443
  protocol           = "TCP"
  vpc_id             = module.vpc.vpc_id
  target_type        = "ip"
  preserve_client_ip = false

  health_check {
    protocol            = "TCP"
    port                = 6443
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 10
  }
}
# 3. Forward TCP 6443 traffic from the NLB to the Target Group
resource "aws_lb_listener" "k8s_api" {
  count             = var.control_plane_count > 1 ? 1 : 0
  load_balancer_arn = aws_lb.k8s_api[0].arn
  port              = 6443
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.k8s_api[0].arn
  }
}

# 4. Register all 3 Master EC2 instances with the Target Group
resource "aws_lb_target_group_attachment" "control_plane" {
  count            = var.control_plane_count > 1 ? var.control_plane_count : 0
  target_group_arn = aws_lb_target_group.k8s_api[0].arn
  target_id        = module.servers.control_plane_private_ips_list[count.index]
  port             = 6443
}

