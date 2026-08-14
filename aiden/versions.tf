terraform {
  required_version = ">= 1.8"

  required_providers {
    sg = {
      source  = "releases.stackgen.com/stackgen/stackgen"
      version = ">= 0.1.25, < 0.2.0"
    }
  }
}

provider "sg" {
  stackgen_url      = var.stackgen_url
  stackgen_token    = var.stackgen_token
  project_id        = var.stackgen_project_id
  adopt_on_conflict = true
}
