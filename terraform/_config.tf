terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.31.0"
    }

    kubectl = {
      source  = "alekc/kubectl"
      version = "2.1.2"
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

provider "kubectl" {
  // get this from `cat /etc/rancher/k3s/k3s.yaml` then update the IP to 192.168.0.137
  config_path = "~/.kube/homelab"
}

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Terraform = "homelab-terraform"
    }
  }
}

provider "kubernetes" {
  config_path = "~/.kube/homelab"
}
