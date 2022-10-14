########### Providers ############################

provider "aws" {
  region = var.region
}

########### Data and misc ########################

resource "random_string" "env" {
  length  = 4
  special = false
  upper   = false
}

locals {
  name = "${var.name}-${random_string.env.result}"
  tags = merge(
    var.tags,
    {
      "X-Contact"     = var.contact
      "X-Environment" = "kong-mesh-accelerator"
    },
  )
}

########### VPC ##################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.0"

  name = local.name
  cidr = "10.99.0.0/18"

  azs             = ["${var.region}a", "${var.region}b", "${var.region}c"]
  public_subnets  = ["10.99.0.0/24", "10.99.1.0/24", "10.99.2.0/24"]
  private_subnets = ["10.99.3.0/24", "10.99.4.0/24", "10.99.5.0/24"]

  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false
  enable_dns_hostnames   = true
  enable_dns_support     = true

  tags = local.tags
}

locals {
  vpc_id = module.vpc.vpc_id
}

data "aws_vpc" "this" {
  id = module.vpc.vpc_id
}

data "aws_subnets" "this" {
  filter {
    name   = "vpc-id"
    values = [module.vpc.vpc_id]
  }

  tags = {
    Name = "*private*"
  }
}

########### Data and misc ########################

data "aws_eks_cluster" "global_cp_cluster" {
  name = module.cluster-1.0.cluster_id
}

data "aws_eks_cluster_auth" "global_cp_cluster" {
  name = module.cluster-1.0.cluster_id
}

########### Global CP Cluster ####################

provider "kubernetes" {
  alias                  = "cluster_1"
  host                   = data.aws_eks_cluster.cluster-1.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster-1.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster-1.token
}

provider "kubernetes" {
  alias                  = "cluster_1"
  host                   = data.aws_eks_cluster.cluster-1.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster-1.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster-1.token
}

provider "flux" {}

provider "kubectl" {
  alias                  = "cluster_1"
  host                   = data.aws_eks_cluster.cluster-1.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster-1.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster-1.token
}

provider "github" {
  alias = "cluster_1"
  owner = var.github_owner
  token = var.github_token
}

module "cluster-1" {
  count = var.cluster_1_create ? 1 : 0
  providers = {
    kubernetes = kubernetes.cluster_1
  }
  source                          = "terraform-aws-modules/eks/aws"
  version                         = "18.29.0"
  cluster_name                    = "cluster-1-${local.name}"
  cluster_version                 = var.eks_kubernetes_version
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true
  enable_irsa                     = true


  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets
  eks_managed_node_groups = {
    global_cp = {
      create_launch_template = false
      launch_template_name   = ""
      disk_size              = 50
      instance_types         = [var.eks_instance_size]
      min_size               = var.eks_min_size
      max_size               = var.eks_max_size
      desired_size           = var.eks_desired_size
      tags                   = local.tags
    }
  }
  cluster_tags = local.tags
  tags         = local.tags
}


resource "kubernetes_namespace" "flux_system" {
  provider = kubernetes.cluster_1
  metadata {
    name = "flux-system"
  }

  lifecycle {
    ignore_changes = [
      metadata[0].labels,
    ]
  }
}

module "cluster_1_flux_bootstrap" {
  source = "../../"
  provider = {
    kubernetes = kubernetes.cluster_1
    kubectl = kubectl.cluster_1
    github = github.cluster_1
  }
  github_owner = "my_github_owner"
  github_token = "my_github_token"
  repository_name = "my_repo"
}
