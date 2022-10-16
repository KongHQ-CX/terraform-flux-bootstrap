locals {
  known_hosts = "github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg="
}

data "flux_install" "main" {
  target_path = var.target_path
}

data "flux_sync" "main" {
  target_path = var.target_path
  url         = "ssh://git@github.com/${var.github_owner}/${var.repository_name}.git"
  branch      = var.branch
}

data "kubectl_file_documents" "install" {
  content = data.flux_install.main.content
}

data "kubectl_file_documents" "sync" {
  content = data.flux_sync.main.content
}

locals {
  install = [for v in data.kubectl_file_documents.install.documents : {
    data : yamldecode(v)
    content : v
    }
  ]
  sync = [for v in data.kubectl_file_documents.sync.documents : {
    data : yamldecode(v)
    content : v
    }
  ]
}

resource "tls_private_key" "main" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}


# can not use this until https://github.com/fluxcd/terraform-provider-flux/issues/67 is fixed
#resource "kubernetes_namespace" "flux_system" {
#  metadata {
#    name = "flux-system"
#  }
#
#  lifecycle {
#    ignore_changes = [
#      metadata[0].labels,
#    ]
#  }
#}

# because of this issue: https://github.com/fluxcd/terraform-provider-flux/issues/67
# we will create the namespace like this:
resource "null_resource" "flux_namespace" {
  triggers = {
    namespace       = var.namespace
    cluster_context = var.cluster_context
    cluster_id      = var.cluster_id

  }

  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --name ${self.triggers.cluster_id}"
  }

  provisioner "local-exec" {
    command = "kubectl --context ${self.triggers.cluster_contex} create namespace ${self.triggers.namespace}"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "aws eks update-kubeconfig --name ${self.triggers.cluster_id}"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "kubectl --context ${self.triggers.cluster_context} delete namespace ${self.triggers.namespace} --cascade=true --wait=false && sleep 120"
  }

  provisioner "local-exec" {
    when       = destroy
    command    = "kubectl --context ${self.triggers.cluster_context} patch customresourcedefinition helmcharts.source.toolkit.fluxcd.io helmreleases.helm.toolkit.fluxcd.io helmrepositories.source.toolkit.fluxcd.io kustomizations.kustomize.toolkit.fluxcd.io -p '{\"metadata\":{\"finalizers\":null}}'"
    on_failure = continue
  }
}

resource "kubectl_manifest" "install" {
  for_each   = { for v in local.install : lower(join("/", compact([v.data.apiVersion, v.data.kind, lookup(v.data.metadata, "namespace", ""), v.data.metadata.name]))) => v.content }
  depends_on = [kubernetes_namespace.flux_system]
  yaml_body  = each.value
}

resource "kubectl_manifest" "sync" {
  for_each   = { for v in local.sync : lower(join("/", compact([v.data.apiVersion, v.data.kind, lookup(v.data.metadata, "namespace", ""), v.data.metadata.name]))) => v.content }
  depends_on = [kubernetes_namespace.flux_system]
  yaml_body  = each.value
}

resource "kubernetes_secret" "main" {
  depends_on = [kubectl_manifest.install]

  metadata {
    name      = data.flux_sync.main.secret
    namespace = data.flux_sync.main.namespace
  }

  data = {
    identity       = tls_private_key.main.private_key_pem
    "identity.pub" = tls_private_key.main.public_key_pem
    known_hosts    = local.known_hosts
  }
}

resource "github_branch_default" "main" {
  repository = var.repository_name
  branch     = var.branch
}

resource "github_repository_deploy_key" "main" {
  title      = "staging-cluster"
  repository = var.repository_name
  key        = tls_private_key.main.public_key_openssh
  read_only  = true
}

resource "github_repository_file" "install" {
  repository          = var.repository_name
  file                = data.flux_install.main.path
  content             = data.flux_install.main.content
  branch              = var.branch
  overwrite_on_create = true
}

resource "github_repository_file" "sync" {
  repository          = var.repository_name
  file                = data.flux_sync.main.path
  content             = data.flux_sync.main.content
  branch              = var.branch
  overwrite_on_create = true
}

resource "github_repository_file" "kustomize" {
  repository          = var.repository_name
  file                = data.flux_sync.main.kustomize_path
  content             = data.flux_sync.main.kustomize_content
  branch              = var.branch
  overwrite_on_create = true
}
