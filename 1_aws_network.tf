# Copyright IBM Corp. 2024, 2026

data "aws_availability_zones" "available" {
  filter {
    name   = "zone-type"
    values = ["availability-zone"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

data "aws_ec2_instance_type_offerings" "supported" {
  location_type = "availability-zone"

  filter {
    name   = "instance-type"
    values = [var.instance_type]
  }
}

locals {
  candidate_azs = [
    for az in data.aws_availability_zones.available.names : az
    if contains(data.aws_ec2_instance_type_offerings.supported.locations, az)
  ]

  sorted_candidate_azs = sort(local.candidate_azs)

  azs = slice(
    local.sorted_candidate_azs,
    0,
    min(length(local.sorted_candidate_azs), 3)
  )
}

module "vpc" {
  source             = "app.terraform.io/benoitblais-hashicorp/vpc/aws"
  version            = "~> 0.0.1"
  name               = "${local.resources_prefix}-vpc"
  cidr               = var.vpc_cidr
  azs                = local.azs
  enable_nat_gateway = true
  single_nat_gateway = true
  private_subnets    = [for idx, az in local.azs : cidrsubnet(var.vpc_cidr, 4, idx)]
  public_subnets     = [for idx, az in local.azs : cidrsubnet(var.vpc_cidr, 8, idx + 48)]

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }
}
