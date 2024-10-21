terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.31.0"
    }

    consul = {
      source  = "hashicorp/consul"
      version = "2.20.0"
    }

    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "4.15.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "2.16.1"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.33.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "3.5.1"
    }
  }

  backend "s3" {
    bucket  = "jjti-homelab-state"
    key     = "state.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Terraform = "homelab-terraform"
    }
  }
}

provider "cloudflare" {}

provider "consul" {
  address = "http://192.168.0.137:8500"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}
