module "kms" {
  source           = "../../modules/kms"
  name             = "${var.name}-platform"
  description      = "Nova Bank platform key (secrets, ECR, EKS, RDS, CloudTrail)"
  allow_cloudtrail = true
}

module "network" {
  source             = "../../modules/network"
  name               = var.name
  region             = var.region
  cluster_name       = var.name
  azs                = var.azs
  single_nat_gateway = var.single_nat_gateway
}

module "ecr" {
  source      = "../../modules/ecr"
  name_prefix = "novabank"
  kms_key_arn = module.kms.key_arn
}

module "eks" {
  source               = "../../modules/eks"
  cluster_name         = var.name
  private_subnet_ids   = module.network.private_subnet_ids
  public_access_cidrs  = [var.admin_ip_cidr]
  admin_principal_arns = var.admin_principal_arns
  kms_key_arn          = module.kms.key_arn
}

module "secrets" {
  source      = "../../modules/secrets"
  kms_key_arn = module.kms.key_arn
  db_hosts = {
    dev  = "postgres.novabank-dev.svc.cluster.local"
    prod = module.rds.endpoint_address
  }
}

module "rds" {
  source                     = "../../modules/rds"
  name                       = var.name
  vpc_id                     = module.network.vpc_id
  data_subnet_ids            = module.network.data_subnet_ids
  allowed_security_group_ids = [module.eks.cluster_security_group_id]
  kms_key_arn                = module.kms.key_arn
  db_password                = module.secrets.db_passwords["prod"]
  multi_az                   = var.rds_multi_az
}

module "iam" {
  source              = "../../modules/iam"
  name                = var.name
  oidc_provider_arn   = module.eks.oidc_provider_arn
  oidc_issuer_host    = module.eks.oidc_issuer_host
  secret_arns         = module.secrets.secret_arns
  kms_key_arn         = module.kms.key_arn
  ecr_repository_arns = module.ecr.repository_arns
}

module "security" {
  source      = "../../modules/security"
  name        = var.name
  kms_key_arn = module.kms.key_arn
}

module "observability" {
  source          = "../../modules/observability"
  name            = var.name
  alert_email     = var.alert_email
  rds_instance_id = module.rds.instance_id
}

module "cost" {
  source            = "../../modules/cost"
  name              = var.name
  monthly_limit_usd = var.monthly_budget_usd
  alert_email       = var.alert_email
}

module "dr" {
  source    = "../../modules/dr"
  name      = var.name
  dr_region = var.dr_region
  providers = {
    aws    = aws
    aws.dr = aws.dr
  }
}
