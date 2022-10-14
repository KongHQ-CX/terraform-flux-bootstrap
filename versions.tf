terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = ">= 4.5.2"
    }

    flux = {
      source  = "fluxcd/flux"
      version = "0.19.0"
    }

    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.10.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.2"
    }
  }
}
