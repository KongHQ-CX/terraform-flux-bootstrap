# terraform-flux-bootstrap

A terraform module for bootstrapping flux into a kubernetes cluster

## Usage

### Using module defaults

The following will bootstrap the flux controller into an cluster

```HCL
module "cluster_1_flux_bootstrap" {
  source = "KongHQ-CX/bootstrap/flux"
  provider = {
    kubernetes = kubernetes.cluster_1
    kubectl = kubectl.cluster_1
    github = github.cluster_1
  }
  github_owner = "my_github_owner"
  github_token = "my_github_token"
  repository_name = "my_repo"
}
```
