terraform {
  required_version = ">= 1.6"
  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 5.80" }
    random = { source = "hashicorp/random", version = "~> 3.6" }
    tls    = { source = "hashicorp/tls", version = "~> 4.0" }
  }
  backend "s3" {}
}

locals {
  tags = { Project = "nova-bank", Env = "prod", Owner = "charan", ManagedBy = "terraform" }
}

provider "aws" {
  region = var.region
  default_tags { tags = local.tags }
}

provider "aws" {
  alias  = "dr"
  region = var.dr_region
  default_tags { tags = local.tags }
}
