resource "aws_iam_policy" "services_policy" {
  name        = var.policy_name
  description = "Permissions for EBS, ELB, Target Groups, and S3 access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ec2:CreateVolume", "ec2:DeleteVolume"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["elasticloadbalancing:*"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:*"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role" "services_role" {
  name = var.role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "attach_custom" {
  role       = aws_iam_role.services_role.name
  policy_arn = aws_iam_policy.services_policy.arn
}

resource "aws_iam_instance_profile" "profile" {
  name = "services-role-profile"
  role = aws_iam_role.services_role.name
}


resource "aws_iam_role_policy" "aws_ccm_policy" {
  name = "AWSCloudControllerManagerPolicy"
  role = aws_iam_role.services_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          # EC2 Instance & Topology Discovery
          "ec2:DescribeInstances",
          "ec2:DescribeRegions",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeRouteTables",
          "ec2:DescribeSubnets",
          "ec2:DescribeVolumes",
          "ec2:CreateTags",
          "ec2:AttachVolume",
          "ec2:DetachVolume",
          
          # Describe toploy constrain

          "ec2:DescribeInstanceTopology",
          
          # Security Group Management (Fixes AuthorizeSecurityGroupIngress error)
          "ec2:DescribeSecurityGroups",
          "ec2:CreateSecurityGroup",
          "ec2:DeleteSecurityGroup",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupEgress",

          # Elastic Load Balancing
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeLoadBalancerAttributes",
          "elasticloadbalancing:CreateLoadBalancer",
          "elasticloadbalancing:DeleteLoadBalancer",
          "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
          "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
          "elasticloadbalancing:ConfigureHealthCheck",
          "elasticloadbalancing:CreateLoadBalancerListeners",
          "elasticloadbalancing:DeleteLoadBalancerListeners",
          "elasticloadbalancing:ModifyLoadBalancerAttributes"
        ]
        Resource = "*"
      }
    ]
  })
}