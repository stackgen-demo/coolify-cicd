# Aiden workflows

This root deploys the three custom demo workflows plus the pinned Guild supply-chain and Grafana SRE modules. Module sources are pinned to Guild-Solutions commit `b6050e5e4275e05303a769b3688088ac509449c2`.

Required deployment inputs are StackGen URL, PAT, and human workspace name. Resolve the workspace UUID before planning:

```bash
python3 ../skills/aiden-workflow-deployer/scripts/resolve_workspace_uuid.py \
  --stackgen-url "$STACKGEN_URL" \
  --stackgen-token "$STACKGEN_TOKEN" \
  --workspace-name "$WORKSPACE_NAME"
```

Inventory the workspace before planning so the root reuses existing models,
integrations, policies, and remote runners instead of recreating them:

```bash
python3 ../skills/aiden-workflow-deployer/scripts/discover_workspace.py \
  --stackgen-url "$STACKGEN_URL" \
  --stackgen-token "$STACKGEN_TOKEN" \
  --stackgen-project-id "$STACKGEN_PROJECT_ID"
```

`Demo Workspace` currently resolves to project
`62e29120-d230-4d4c-ba0d-3426e887d697`. This root is configured to reuse
`github-integration`, `sandbox-grafana`, `stackgen-sandbox`, `demo-runner`, and
the selected workspace model and shared policies. It does not need their
underlying credential values.

Set the real GitHub `owner/repository` and the dedicated GitHub App bot login
in an uncommitted tfvars file. Supply only the StackGen PAT through the
environment:

```bash
export TF_VAR_stackgen_token="$STACKGEN_TOKEN"
tofu init
tofu fmt -check -recursive
tofu validate
tofu plan -out=tfplan
tofu show -json tfplan | jq -r '.resource_changes[] | [.address, (.change.actions | join(","))] | @tsv'
```

Stop if the plan contains a delete, replacement, workspace UUID change, or
unrelated resource. Apply only the reviewed saved plan. After apply, store the
three sensitive webhook payload URLs as GitHub Actions secrets; never print or
commit them.
