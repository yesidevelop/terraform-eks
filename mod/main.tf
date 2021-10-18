resource "aws_eks_cluster" "cluster" {
  name     = var.environment_name
  role_arn = aws_iam_role.cluster.arn

  version = var.cluster_version

  vpc_config {
    endpoint_private_access = var.cluster_private_access
    endpoint_public_access  = var.cluster_public_access
    public_access_cidrs     = var.cluster_public_access_cidrs

    security_group_ids = [aws_security_group.cluster.id]

    subnet_ids = flatten([
      aws_subnet.public.*.id,
      aws_subnet.private.*.id,
    ])
  }

  enabled_cluster_log_types = var.cluster_logging

  depends_on = [
    aws_iam_role_policy_attachment.cluster-AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.cluster-AmazonEKSServicePolicy,
  ]

  tags = {
    "KubespotEnvironment" = var.environment_name
  }
}

resource "aws_eks_node_group" "green" {
  cluster_name    = aws_eks_cluster.cluster.name
  node_group_name = "custer-nodegroup-green"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = aws_subnet.public.*.id
  instance_types  = [ var.nodes_green_instance_type ]

  scaling_config {
    desired_size = var.nodes_green_desired_capacity
    max_size     = var.nodes_green_max_size
    min_size     = var.nodes_green_min_size
  }

  update_config {
    max_unavailable = var.nodes_green_max_unavailable
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_iam_role_policy_attachment.node-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node-AmazonEC2ContainerRegistryReadOnly,
  ]
}

resource "aws_eks_node_group" "blue" {
  cluster_name    = aws_eks_cluster.cluster.name
  node_group_name = "custer-nodegroup-blue"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = aws_subnet.public.*.id

  scaling_config {
    desired_size = var.nodes_blue_desired_capacity
    max_size     = var.nodes_blue_max_size
    min_size     = var.nodes_blue_min_size
  }

  update_config {
    max_unavailable = var.nodes_blue_max_unavailable
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_iam_role_policy_attachment.node-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node-AmazonEC2ContainerRegistryReadOnly,
  ]
}

resource "time_sleep" "wait_5_minutes" {
  # depends_on = [kubernetes_config_map.aws_auth]

  create_duration = "5m"
}

resource "aws_eks_addon" "core" {
  for_each = toset([
    "kube-proxy",
    "vpc-cni",
    "coredns"
  ])

  cluster_name      = aws_eks_cluster.cluster.name
  addon_name        = each.key
  resolve_conflicts = "OVERWRITE"

  depends_on = [
    time_sleep.wait_5_minutes
  ]
}

# EKS currently documents this required userdata for EKS worker nodes to
# properly configure Kubernetes applications on the EC2 instance.
# We utilize a Terraform local here to simplify Base64 encoding this
# information into the AutoScaling Launch Configuration.
# More information: https://amazon-eks.s3-us-west-2.amazonaws.com/1.10.3/2018-06-05/amazon-eks-nodegroup.yaml
# locals {
#   node-userdata = <<USERDATA
# #!/bin/bash -xe
# set -o xtrace

# /etc/eks/bootstrap.sh --apiserver-endpoint '${aws_eks_cluster.cluster.endpoint}' --b64-cluster-ca '${aws_eks_cluster.cluster.certificate_authority[0].data}' '${var.environment_name}'
# USERDATA

# }

# resource "aws_launch_configuration" "nodes_blue" {
#   iam_instance_profile        = aws_iam_instance_profile.node.name
#   image_id                    = var.ami_image == "" ? data.aws_ssm_parameter.eks_ami.value : var.ami_image
#   instance_type               = var.nodes_blue_instance_type
#   name_prefix                 = "${var.environment_name}-nodes-blue"
#   security_groups             = [aws_security_group.node.id]
#   user_data_base64            = base64encode(local.node-userdata)
#   associate_public_ip_address = var.nodes_in_public_subnet

#   key_name = var.ec2_keypair

#   root_block_device {
#     volume_size = var.nodes_blue_root_device_size
#     encrypted   = true
#   }

#   lifecycle {
#     create_before_destroy = true
#   }
# }

# resource "aws_autoscaling_group" "nodes_blue" {
#   desired_capacity      = var.nodes_blue_desired_capacity
#   launch_configuration  = aws_launch_configuration.nodes_blue.id
#   max_size              = var.nodes_blue_max_size
#   min_size              = var.nodes_blue_min_size
#   name                  = "${var.environment_name}-nodes-blue"
#   max_instance_lifetime = var.nodes_blue_max_instance_lifetime

#   vpc_zone_identifier = length(var.nodes_blue_subnet_ids) == 0 ? (var.nodes_in_public_subnet ? aws_subnet.public.*.id : aws_subnet.private.*.id) : var.nodes_blue_subnet_ids

#   enabled_metrics = var.enabled_metrics_asg

#   tags = [
#     {
#       key                 = "Name"
#       value               = "${var.environment_name}-nodes-blue"
#       propagate_at_launch = true
#     },
#     {
#       key                 = "kubernetes.io/cluster/${var.environment_name}"
#       value               = "owned"
#       propagate_at_launch = true
#     },
#     {
#       key                 = "k8s.io/cluster-autoscaler/${var.environment_name}"
#       value               = "owned"
#       propagate_at_launch = true
#     },
#     {
#       key                 = "k8s.io/cluster-autoscaler/enabled"
#       value               = "TRUE"
#       propagate_at_launch = true
#     },
#     {
#       key                 = "KubespotEnvironment"
#       value               = var.environment_name
#       propagate_at_launch = true
#     },
#   ]
# }

# resource "aws_launch_configuration" "nodes_green" {
#   iam_instance_profile        = aws_iam_instance_profile.node.name
#   image_id                    = var.ami_image == "" ? data.aws_ssm_parameter.eks_ami.value : var.ami_image
#   instance_type               = var.nodes_green_instance_type
#   name_prefix                 = "${var.environment_name}-nodes-green"
#   security_groups             = [aws_security_group.node.id]
#   user_data_base64            = base64encode(local.node-userdata)
#   associate_public_ip_address = var.nodes_in_public_subnet

#   key_name = var.ec2_keypair

#   root_block_device {
#     volume_size = var.nodes_green_root_device_size
#     encrypted   = true
#   }

#   lifecycle {
#     create_before_destroy = true
#   }
# }

# resource "aws_autoscaling_group" "nodes_green" {
#   desired_capacity      = var.nodes_green_desired_capacity
#   launch_configuration  = aws_launch_configuration.nodes_green.id
#   max_size              = var.nodes_green_max_size
#   min_size              = var.nodes_green_min_size
#   name                  = "${var.environment_name}-nodes-green"
#   max_instance_lifetime = var.nodes_green_max_instance_lifetime

#   vpc_zone_identifier = length(var.nodes_green_subnet_ids) == 0 ? (var.nodes_in_public_subnet ? aws_subnet.public.*.id : aws_subnet.private.*.id) : var.nodes_green_subnet_ids

#   enabled_metrics = var.enabled_metrics_asg

#   tags = [
#     {
#       key                 = "Name"
#       value               = "${var.environment_name}-nodes-green"
#       propagate_at_launch = true
#     },
#     {
#       key                 = "kubernetes.io/cluster/${var.environment_name}"
#       value               = "owned"
#       propagate_at_launch = true
#     },
#     {
#       key                 = "k8s.io/cluster-autoscaler/${var.environment_name}"
#       value               = "owned"
#       propagate_at_launch = true
#     },
#     {
#       key                 = "k8s.io/cluster-autoscaler/enabled"
#       value               = "TRUE"
#       propagate_at_launch = true
#     },
#     {
#       key                 = "KubespotEnvironment"
#       value               = var.environment_name
#       propagate_at_launch = true
#     },
#   ]
# }

data "aws_caller_identity" "current" {
}


# Run Every time to update instance life time
# resource "null_resource" "update_asg" {
#   triggers = {
#     key = "${uuid()}"
#   }
#   provisioner "local-exec" {
#     command = <<EOT
#       aws autoscaling update-auto-scaling-group --auto-scaling-group-name ${aws_eks_node_group.green.resources[0].autoscaling_groups[0].name} --max-instance-lifetime 31536000
#       aws autoscaling update-auto-scaling-group --auto-scaling-group-name ${aws_eks_node_group.blue.resources[0].autoscaling_groups[0].name} --max-instance-lifetime 31536000
#     EOT
#   }
#   depends_on = [
#     aws_eks_node_group.green,
#     aws_eks_node_group.blue
#   ]
# }