terraform {
  backend "s3" {
    bucket       = "terraform-kofta-s3"
    key          = "terraform.tfstate"
    encrypt      = true
    region       = "eu-north-1"
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }

    ansible = {
      source  = "ansible/ansible"
      version = "~> 1.4.0"
    }
  }
}
