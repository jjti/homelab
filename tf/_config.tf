terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.4.0"
    }

    consul = {
      source  = "hashicorp/consul"
      version = "2.18.0"
    }

    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "4.14.0"
    }

    nomad = {
      source  = "hashicorp/nomad"
      version = "2.0.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "3.5.1"
    }

    minio = {
      source  = "aminueza/minio"
      version = "1.18.0"
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

provider "minio" {
  minio_server = "192.168.0.137:9000"
  minio_user   = "admin"
}

provider "nomad" {
  address = "http://192.168.0.137:4646"
}
