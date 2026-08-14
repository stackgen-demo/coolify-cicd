#!/usr/bin/env python3
"""Resolve a StackGen/Aiden workspace name to a UUID using read-only Terraform data sources."""

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
}

variable "stackgen_url" { type = string }
variable "stackgen_token" {
  type      = string
  sensitive = true
}

data "sg_me" "current" {}
data "sg_organizations" "all" {}

output "lookup" {
  value = {
    memberships   = data.sg_me.current.orgs
    organizations = data.sg_organizations.all.organizations
  }
}
'''


def run(cmd: list[str], cwd: Path, env: dict[str, str]) -> str:
    proc = subprocess.run(
        cmd,
        cwd=str(cwd),
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if proc.returncode != 0:
        sys.stderr.write(proc.stderr)
        raise SystemExit(proc.returncode)
    return proc.stdout


def normalize(value: str) -> str:
    return " ".join(value.casefold().strip().split())


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--stackgen-url",
        default=os.environ.get("STACKGEN_URL") or os.environ.get("TF_VAR_stackgen_url"),
    )
    parser.add_argument(
        "--stackgen-token",
        default=os.environ.get("STACKGEN_TOKEN") or os.environ.get("TF_VAR_stackgen_token"),
    )
    parser.add_argument("--workspace-name", required=True)
    parser.add_argument("--include-memberships", action="store_true")
    args = parser.parse_args()

    if not args.stackgen_url:
        parser.error("--stackgen-url or STACKGEN_URL is required")
    if not args.stackgen_token:
        parser.error("--stackgen-token or STACKGEN_TOKEN is required")

    terraform = shutil.which("tofu") or shutil.which("terraform")
    if not terraform:
        raise SystemExit("error: neither tofu nor terraform is on PATH")

    env = os.environ.copy()
    env["TF_VAR_stackgen_url"] = args.stackgen_url
    env["TF_VAR_stackgen_token"] = args.stackgen_token
    env.setdefault("TF_IN_AUTOMATION", "1")

    with tempfile.TemporaryDirectory(prefix="sg-workspace-lookup-") as tmp:
        work = Path(tmp)
        (work / "main.tf").write_text(TF_MAIN, encoding="utf-8")
        run([terraform, "init", "-input=false"], work, env)
        run([terraform, "apply", "-input=false", "-auto-approve"], work, env)
        raw = run([terraform, "output", "-json", "lookup"], work, env)

    payload = json.loads(raw)
    organizations = payload.get("organizations") or []
    target = normalize(args.workspace_name)
    exact = [item for item in organizations if normalize(item.get("name", "")) == target]
    fuzzy = [
        item
        for item in organizations
        if item not in exact and target in normalize(item.get("name", ""))
    ]

    result = {
        "query": args.workspace_name,
        "selected": exact[0] if len(exact) == 1 else None,
        "exact_matches": sorted(exact, key=lambda item: item.get("name", "")),
        "fuzzy_matches": sorted(fuzzy, key=lambda item: item.get("name", "")),
        "match_count": {
            "exact": len(exact),
            "fuzzy": len(fuzzy),
            "visible_organizations": len(organizations),
        },
    }
    if args.include_memberships:
        result["memberships"] = sorted(
            payload.get("memberships") or [], key=lambda item: item.get("name", "")
        )

    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
