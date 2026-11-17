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


locals {
  name = "storefront-eks"
  azs  = slice(data.aws_availability_zones.available.names, 0, 2)
}