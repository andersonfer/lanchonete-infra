terraform {
  required_version = ">= 1.0"

  required_providers {
    mongodbatlas = {
      source  = "mongodb/mongodbatlas"
      version = "~> 1.15"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

# Provider MongoDB Atlas
# As credenciais sao lidas automaticamente das variaveis de ambiente:
# MONGODB_ATLAS_PUBLIC_KEY e MONGODB_ATLAS_PRIVATE_KEY
provider "mongodbatlas" {}

# Cluster M0 (Free Tier)
resource "mongodbatlas_advanced_cluster" "pagamento" {
  project_id   = var.atlas_project_id
  name         = var.cluster_name
  cluster_type = "REPLICASET"

  replication_specs {
    region_configs {
      electable_specs {
        instance_size = "M0"
      }
      provider_name         = "TENANT"
      backing_provider_name = "AWS"
      region_name           = var.atlas_region
      priority              = 7
    }
  }

  tags {
    key   = "Projeto"
    value = local.common_tags.Projeto
  }

  tags {
    key   = "ManagedBy"
    value = local.common_tags.ManagedBy
  }

  tags {
    key   = "Service"
    value = local.common_tags.Service
  }
}

# Network Access - Permitir acesso de qualquer IP (para POC)
# Em producao, limite aos IPs do cluster EKS/VPC
resource "mongodbatlas_project_ip_access_list" "allow_all" {
  project_id = var.atlas_project_id
  cidr_block = "0.0.0.0/0"
  comment    = "POC - restringir em producao"
}
