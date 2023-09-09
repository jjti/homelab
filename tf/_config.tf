terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.4.0"
    }

    nomad = {
      source  = "hashicorp/nomad"
      version = "2.0.0"
    }

    random = {
      source = "hashicorp/random"
      version = "3.5.1"
    }
  }

  backend "s3" {
    bucket = "jjti-homelab-state"
    key    = "state.tfstate"
    region = "us-east-1"
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

provider "nomad" {
  address = "http://192.168.0.172:4646"
}
