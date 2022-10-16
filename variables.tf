########### Flux settings ########################

variable "github_owner" {
  description = "github owner"
  type        = string
}

variable "github_token" {
  description = "github token"
  type        = string
}

variable "repository_name" {
  description = "github repository name"
  type        = string
}

variable "repository_visibility" {
  description = "How visible is the github repo"
  type        = string
  default     = "private"
}

variable "branch" {
  description = "branch name"
  type        = string
  default     = "main"
}

variable "target_path" {
  description = "flux sync target path"
  type        = string
  default     = "gitops"
}

variable "cluster_context" {
  description = "The context for the kubernetes cluster we are targeting"
  type        = string
}

variable "cluster_id" {
  description = "The ID for the kubernetes cluster we are targeting"
  type        = string
}

variable "namespace" {
  description = "The name space to deploy flux into"
  type        = string
  default     = "flux-system"
}
