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

