#!/usr/bin/env python3
"""Read a sanitized Aiden workspace inventory without managing live resources."""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


TF_MAIN = r'''
terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = {
      source  = "releases.stackgen.com/stackgen/stackgen"
      version = ">= 0.1.25, < 0.2.0"
    }
  }
}

provider "sg" {
  stackgen_url   = var.stackgen_url
  stackgen_token = var.stackgen_token
  project_id     = var.stackgen_project_id
}

variable "stackgen_url" { type = string }
variable "stackgen_token" {
  type      = string
  sensitive = true
}
variable "stackgen_project_id" { type = string }

data "sg_guild_models" "all" {}
data "sg_remote_runners" "all" {}
data "sg_agents" "all" {}
data "sg_workflows" "all" {
  include_drafts = true
  latest_only    = true
  limit          = 100
}
data "sg_webhooks" "all" {
  include_app_only    = true
  include_provisioned = true
}
data "sg_policies" "all" {}

locals {
  integration_names = toset(flatten([
    for agent in data.sg_agents.all.agents : tolist(agent.integrations)
  ]))
}

data "sg_guild_integration" "attached" {
  for_each = local.integration_names
  name     = each.value
}

output "inventory" {
  value = {
    models = [for model in data.sg_guild_models.all.models : {
      name          = model.name
      model_id      = model.model_id
      provider_name = model.provider_name
      scope         = model.scope
    }]
    remote_runners = [for runner in data.sg_remote_runners.all.runners : {
      name            = runner.name
      status          = runner.status
      capabilities    = runner.capabilities
      labels          = runner.labels
      attached_agents = runner.attached_agents
      last_heartbeat  = runner.last_heartbeat
    }]
    integrations = [for name, integration in data.sg_guild_integration.attached : {
      name        = name
      type        = integration.type
      scope       = integration.scope
      enabled     = integration.enabled
      description = integration.description
    }]
    agents = [for agent in data.sg_agents.all.agents : {
      name           = agent.name
      status         = agent.status
      integrations   = tolist(agent.integrations)
      model_names    = tolist(agent.model_names)
      remote_runners = tolist(agent.remote_runners)
    }]
    workflows = [for workflow in data.sg_workflows.all.workflows : {
      name    = workflow.name
      status  = workflow.status
      version = workflow.version
    }]
    webhooks = [for webhook in data.sg_webhooks.all.webhooks : {
      name        = webhook.name
      target_type = webhook.target_type
      target_name = webhook.target_name
      enabled     = webhook.enabled
    }]
    policies = [for policy in data.sg_policies.all.policies : {
      id      = policy.id
      name    = policy.name
      type    = policy.type
      version = policy.version
    }]
  }
}
'''


def run(command: list[str], workdir: Path, environment: dict[str, str]) -> str:
    process = subprocess.run(
        command,
        cwd=workdir,
        env=environment,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if process.returncode != 0:
        sys.stderr.write(process.stderr)
        raise SystemExit(process.returncode)
    return process.stdout


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--stackgen-url", default=os.environ.get("STACKGEN_URL"))
    parser.add_argument("--stackgen-token", default=os.environ.get("STACKGEN_TOKEN"))
    parser.add_argument("--stackgen-project-id", required=True)
    args = parser.parse_args()

    if not args.stackgen_url:
        parser.error("--stackgen-url or STACKGEN_URL is required")
    if not args.stackgen_token:
        parser.error("--stackgen-token or STACKGEN_TOKEN is required")

    tofu = shutil.which("tofu") or shutil.which("terraform")
    if not tofu:
        raise SystemExit("error: neither tofu nor terraform is on PATH")

    environment = os.environ.copy()
    environment.update(
        {
            "TF_IN_AUTOMATION": "1",
            "TF_VAR_stackgen_url": args.stackgen_url,
            "TF_VAR_stackgen_token": args.stackgen_token,
            "TF_VAR_stackgen_project_id": args.stackgen_project_id,
        }
    )

    with tempfile.TemporaryDirectory(prefix="sg-workspace-discovery-") as temp:
        workdir = Path(temp)
        (workdir / "main.tf").write_text(TF_MAIN, encoding="utf-8")
        run([tofu, "init", "-input=false"], workdir, environment)
        run([tofu, "apply", "-input=false", "-auto-approve"], workdir, environment)
        inventory = json.loads(run([tofu, "output", "-json", "inventory"], workdir, environment))

    print(json.dumps(inventory, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
