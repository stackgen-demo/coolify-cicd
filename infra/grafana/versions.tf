terraform {
  required_version = ">= 1.8"

  required_providers {
    grafana = {
      source  = "grafana/grafana"
      version = ">= 4.0, < 5.0"
    }
  }
}

provider "grafana" {
  url  = var.grafana_url
  auth = var.grafana_auth
}
