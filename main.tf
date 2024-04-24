# IAM Role for EKS Cluster

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "example" {
  name               = "eks-cluster-example"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.example.name
}

resource "aws_iam_role_policy_attachment" "eks_vpc_resource_controller" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.example.name
}

# VPC and Subnet Data

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "public" {
  vpc_id = data.aws_vpc.default.id
}

# EKS Cluster Provisioning

resource "aws_eks_cluster" "example" {
  name          = "EKS_CLOUD"
  role_arn      = aws_iam_role.example.arn

  vpc_config {
    subnet_ids         = data.aws_subnet_ids.public.ids
    security_group_ids = [aws_security_group.eks.id]
  }

  # Ensure IAM Role permissions are created before and deleted after EKS Cluster handling.
  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
  ]

  tags = {
    Environment = "Production"
  }
}

# IAM Role for Node Group

resource "aws_iam_role" "node_group" {
  name = "eks-node-group-cloud"

  assume_role_policy = jsonencode({
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }],
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node_group.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node_group.name
}

resource "aws_iam_role_policy_attachment" "ec2_container_registry_readonly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node_group.name
}

# EKS Node Group Creation

resource "aws_eks_node_group" "example" {
  cluster_name  = aws_eks_cluster.example.name
  node_group_name = "Node-cloud"
  node_role_arn  = aws_iam_role.node_group.arn
  subnet_ids    = data.aws_subnet_ids.public.ids

  scaling_config {
