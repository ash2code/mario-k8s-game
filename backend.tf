
terraform {
  backend "s3" {
    bucket = "aws-eks-mariogame-k8s" # Replace with your actual S3 bucket name
    key    = "EKS/terraform.tfstate"
    region = "us-east-1"
  }
}
