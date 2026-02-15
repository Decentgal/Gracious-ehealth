terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"

  # I am automatically tagging every resource created according to NIST/ISO Standard
  default_tags {
    tags = {
      Project           = "Gracious-ehealth"
      Owner             = "Gracious-Onyeahialam"
      Compliance        = "HIPAA-NIST-GDPR"
      ManagedBy         = "Terraform"
    }
  }
}
