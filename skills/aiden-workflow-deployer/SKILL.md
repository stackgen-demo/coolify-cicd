---
name: aiden-workflow-deployer
description: Configure, validate, deploy, update, or troubleshoot Aiden/Guild agents and workflows with Terraform/OpenTofu and the StackGen provider. Use for Aiden workflow roots, sg_agent/sg_workflow/sg_webhook resources, Guild integrations and policies, schedules, workspace resolution, additive plans, or the Talkdesk Coolify security and observability agents in this repository.
---

# Aiden Workflow Deployer

Deploy Aiden resources as code while preserving live workspace resources and secrets.

## Read First

1. Read the nearest repository `AGENTS.md`.
2. Read `/Users/arunav/Documents/GitHub/Guild-Solutions/AGENTS.md`.
3. For this repository, read `references/talkdesk-demo-contract.md`.
4. Read `references/resource-patterns.md` when authoring or changing HCL resources.
5. Read each selected Guild-Solutions module's `variables.tf`, `outputs.tf`, and `README.md`. Treat `variables.tf` as authoritative.

## Required Inputs

Request only these identifiers for the StackGen workspace:

- StackGen URL
- StackGen PAT
- Human workspace name

Never ask for or guess a workspace UUID. Resolve it with:

```bash
python3 skills/aiden-workflow-deployer/scripts/resolve_workspace_uuid.py \
  --stackgen-url "$STACKGEN_URL" \
  --stackgen-token "$STACKGEN_TOKEN" \
  --workspace-name "$WORKSPACE_NAME"
```

Use the selected exact match as `stackgen_project_id`. If there is not exactly one case-insensitive exact match, stop and present the visible matches.

Discover existing GitHub, AWS, Grafana, Ubuntu, Slack, and model secrets or integrations from the current Terraform root and workspace. Reuse them. Do not request or commit their credential values.

For a sanitized, read-only workspace inventory, run:

```bash
python3 skills/aiden-workflow-deployer/scripts/discover_workspace.py \
  --stackgen-url "$STACKGEN_URL" \
  --stackgen-token "$STACKGEN_TOKEN" \
  --stackgen-project-id "$STACKGEN_PROJECT_ID"
```

## Deployment Workflow

1. **Inspect before changing.** Search for `*.tf`, state files, tfvars, module sources, workflow names, and existing integrations. Run `tofu state list` for candidate roots.
2. **Select one owner root.** Prefer the root already managing related resources. For this repository use `aiden/` unless an existing state proves another root owns them.
3. **Resolve the workspace UUID.** Set provider `project_id` to the UUID, never the display name.
4. **Compose layers in order.** Foundation and policies, integrations, agents/runbooks/workflows, then webhooks and schedules.
5. **Prefer modules.** Use pinned modules from `/Users/arunav/Documents/GitHub/Guild-Solutions`. Hand-author `sg_*` resources only when no module implements the required behavior.
6. **Use collision-safe names.** Reuse existing names or add a stable `name_suffix`. Do not create duplicate live agents or workflows in a second state.
7. **Keep writes bounded.** Agents are read-only by default. Attach `dangerous_ops`; require HITL for repository administration, deployment, remediation, or cloud mutation except for the contract's narrowly scoped security-controls auto-merge and application-branch update.
8. **Validate locally.** Run formatting, initialization, validation, relevant tests, and a saved plan.
9. **Inspect the plan.** Reject deletes, replacements, project/provider drift, and unrelated changes. Apply only the reviewed saved plan.
10. **Verify live resources.** Report agent/workflow names, webhook endpoints, schedules, and test invocation results without exposing tokens.

## Safe Commands

```bash
tofu -chdir=aiden fmt -check -recursive
tofu -chdir=aiden init -input=false
tofu -chdir=aiden validate
tofu -chdir=aiden plan -input=false -out=tfplan
tofu -chdir=aiden show -json tfplan \
  | jq -r '.resource_changes[] | [.address, (.change.actions | join(","))] | @tsv'
```

Apply only after every action is expected and no action contains `delete`:

```bash
tofu -chdir=aiden apply tfplan
```

When changing the shared Guild-Solutions repository, also run:

```bash
make -C /Users/arunav/Documents/GitHub/Guild-Solutions verify-workflow-stage-bindings
```

## Non-Negotiable Guardrails

- Configure `adopt_on_conflict = true` for additive customer deployments.
- Never hard-code PATs, API keys, passwords, webhook tokens, model keys, or backend credentials.
- Never print sensitive Terraform outputs or save secrets in tfvars, plans committed to Git, workflow descriptions, or reports.
- Never silently replace an integration, agent, workflow, webhook, or policy managed by another state.
- Never auto-approve a PR. Never auto-merge except for the `security-control-bootstrap` exception explicitly authorized in `references/talkdesk-demo-contract.md`; that exception cannot merge application code.
- Keep webhook payloads and runbook output free of raw credentials and unnecessary customer data.
- Give each agent a daily budget and each active probe a target allowlist, request limit, and time limit.
- Do not add a `codex` prefix to branches or Codex co-author trailers to commits.

## Failure Handling

- Missing existing integration or secret: report its required type and stop before apply.
- Ambiguous workspace match: show matches and request selection by name.
- Existing live name outside current state: add a suffix or propose import; do not adopt implicitly.
- Plan contains delete or replace: abort and explain the owning resource and likely state conflict.
- Webhook test fails: keep resources deployed, report the HTTP/status evidence, and do not rotate tokens unless asked.
- Security-controls PR validation, identity, path, template digest, base branch, check, or head-SHA guard fails: do not merge or update the application branch; comment with the failed guard and escalate.

## Delivery Report

Include the resolved workspace name/UUID, Terraform root, reused and created modules, plan action summary, explicit confirmation of zero deletes, apply result, workflow/agent names, webhook setup status, and any unmet integration prerequisite. Redact all sensitive values.
