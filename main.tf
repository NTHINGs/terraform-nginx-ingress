terraform {
  required_providers {
    helm = "~> 1.0"
  }

#   backend "remote" {
#     hostname     = "app.terraform.io"
#     organization = "tecnoly"

#     workspaces {
#       name = "terraform-nginx-ingress"
#     }
#   }
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

resource "google_compute_address" "ip_address" {
  name = "nginx-ip"
}

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

data "template_file" "values" {
  template = file("${path.module}/values.tmpl")
  vars = {
    reserved_address = google_compute_address.ip_address.address
  }
}

resource "helm_release" "nginx_ingress" {
  name          = "nginx-ingress"
  repository    = data.helm_repository.stable.metadata[0].name
  chart         = "nginx-ingress"
  version       = "1.33.0"
  namespace     = kubernetes_namespace.nginx_ingress.id

  values = [
    data.template_file.values.rendered
  ]
}