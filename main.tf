terraform {
  required_providers {
    helm = "~> 1.0"
  }
}

data "terraform_remote_state" "cluster" {
  backend = "remote"

  config = {
    hostname     = "app.terraform.io"
    organization = "tecnoly"

    workspaces = {
      name = "gke-cluster"
    }
  }
}

data "google_client_config" "current" {}

provider "kubernetes" {
  load_config_file       = false
  host                   = "https://${data.terraform_remote_state.cluster.outputs.cluster_endpoint}"
  cluster_ca_certificate = base64decode(data.terraform_remote_state.cluster.outputs.cluster_ca_certificate)
  token                  = data.google_client_config.current.access_token
}

resource "kubernetes_namespace" "nginx_ingress" {
  metadata {
    name = "nginx-ingress"
  }
}

provider "helm" {
  kubernetes {
    load_config_file       = false
    host                   = "https://${data.terraform_remote_state.cluster.outputs.cluster_endpoint}"
    cluster_ca_certificate = base64decode(data.terraform_remote_state.cluster.outputs.cluster_ca_certificate)
    token                  = data.google_client_config.current.access_token
  }
}

data "helm_repository" "stable" {
  name = "stable"
  url  = "https://kubernetes-charts.storage.googleapis.com"
}

resource "helm_release" "nginx_ingress" {
  name          = "nginx-ingress"
  repository    = data.helm_repository.stable.metadata[0].name
  chart         = "nginx-ingress"
  version       = "1.33.0"
  namespace     = kubernetes_namespace.nginx_ingress.id

  values = [
    file("${path.module}/values.yaml"),
  ]
}