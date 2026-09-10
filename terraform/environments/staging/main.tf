provider "aws" {
  region = var.region

  default_tags {
    tags = local.tags
  }
}

locals {
  name_prefix  = "platform-${var.environment}"
  cluster_name = "platform-${var.environment}-eks"
  namespace    = "platform-${var.environment}"

  tags = {
    Project     = "kubernetes-platform-gitops"
    Environment = var.environment
    ManagedBy   = "terraform"
    Owner       = var.owner
  }
}

module "vpc" {
  source = "../../modules/vpc"

  name_prefix          = local.name_prefix
  cluster_name         = local.cluster_name
  cidr_block           = var.vpc_cidr
  azs                  = var.azs
  private_subnet_cidrs = var.private_subnet_cidrs
  public_subnet_cidrs  = var.public_subnet_cidrs
  single_nat_gateway   = var.environment != "prod"
  tags                 = local.tags
}

module "kms" {
  source = "../../modules/kms"

  name_prefix        = local.name_prefix
  service_principals = ["eks.amazonaws.com"]
  tags               = local.tags
}

module "ecr" {
  source = "../../modules/ecr"

  repository_name = "platform-api"
  kms_key_arn     = module.kms.key_arn
  tags            = local.tags
}

module "eks" {
  source = "../../modules/eks"

  name_prefix         = local.name_prefix
  cluster_name        = local.cluster_name
  kubernetes_version  = var.kubernetes_version
  vpc_id              = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.private_subnet_ids
  public_subnet_ids   = module.vpc.public_subnet_ids
  kms_key_arn         = module.kms.key_arn
  node_instance_types = var.node_instance_types
  node_desired_size   = var.node_desired_size
  node_min_size       = var.node_min_size
  node_max_size       = var.node_max_size
  tags                = local.tags
}

module "iam" {
  source = "../../modules/iam"

  name_prefix            = local.name_prefix
  oidc_provider_arn      = module.eks.oidc_provider_arn
  oidc_provider_url      = module.eks.oidc_provider_url
  namespace              = local.namespace
  service_account_name   = "platform-api"
  secrets_manager_prefix = "platform/${var.environment}/platform-api"
  gha_oidc_enabled       = var.gha_oidc_enabled
  gha_repository          = var.gha_repository
  ecr_repository_arn     = module.ecr.repository_arn
  tags                   = local.tags
}
