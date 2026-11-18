terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
  }
}

provider "aws" {
  region = "eu-north-1"
}

data "aws_availability_zones" "available" {
  state = "available"
}

# Keep the the eks only on two AZs. 
locals {
  name = "storefront-eks"
  azs  = slice(data.aws_availability_zones.available.names, 0, 2)
}


module "vpc" {

    source = "terraform-aws-modules/vpc/aws"
    version = "~> 5.13"

    name = "${local.name}-vpc"
    cidr = "10.0.0.0/16"

    # Isolating the worker nodes in private subnets.
    azs = local.azs
    private_subnets = ["10.0.1.0/24" , "10.0.2.0/24"] 
    public_subnets = ["10.0.101.0/24" , "10.0.102.0/24"] 

    enable_nat_gateway =  true
    single_nat_gateway = true
    enable_dns_hostnames = true

    public_subnet_tags = {
        "kubernetes.io/role/elb" = 1
    }

    private_subnet_tags = {
        "kubernetes.io/role/internal-elb" = 1
    }
}


module "eks" {

    source = "terraform-aws-modules/eks/aws"
    version = "~> 20.24"

    cluster_name = local.name
    cluster_version = "1.31"

    cluster_endpoint_public_access = true
    enable_cluster_creator_admin_permissions = true

    vpc_id = module.vpc.vpc_id
    subnet_ids = module.vpc.private_subnets

    cluster_addons = {
        coredns = {}
        eks-pod-identity-agent = {}
        kube-proxy = {}
        vpc-cni = {}
    }

    eks_managed_node_groups = {
        default = {
            # Amazon Linux 2023 AMI
            ami_type = "AL2023_x86_64_STANDARD"
            instance_types = ["t3.medium"]
            min_size = 2
            max_size = 3
            desired_size = 2
        }
    }

    tags = {
        Environment = "demo"
        Owner       = "platform-enablement"
    }

}

