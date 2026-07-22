terraform {
  required_providers {
    kind = {
      source  = "tehcyx/kind"
      version = "~> 0.9"
    }
  }
}

resource "kind_cluster" "this" {
  name           = var.cluster_name
  node_image     = "kindest/node:v1.29.2"
  wait_for_ready = true

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    node {
      role = "control-plane"
      extra_port_mappings {
        container_port = 30080
        host_port      = 8080
      }
      extra_port_mappings {
        container_port = 30030
        host_port      = 3000
      }
    }
    node {
      role = "worker"
    }
  }
}
