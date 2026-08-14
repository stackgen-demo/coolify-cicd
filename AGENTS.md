# Agent Instructions

These instructions apply to the entire repository.

## Aiden and Guild Work

For any Aiden/Guild agent, workflow, webhook, schedule, policy, integration, or StackGen Terraform work, read and follow:

- `skills/aiden-workflow-deployer/SKILL.md`
- `skills/aiden-workflow-deployer/references/talkdesk-demo-contract.md`
- `/Users/arunav/Documents/GitHub/Guild-Solutions/AGENTS.md`

Use `/Users/arunav/Documents/GitHub/Guild-Solutions` as the authoritative local module framework. Read a module's `variables.tf`, `outputs.tf`, and README before using it.

## Repository Layout

- `app/`: sample application and OpenTelemetry instrumentation
- `infra/aws/`: EC2, Coolify, ALB, WAF, TLS, networking, evidence storage
- `infra/grafana/`: ObserveNow dashboards and alert rules
- `aiden/`: StackGen provider root and Aiden resources
- `policies/`: deterministic OPA controls
- `skills/`: reusable agent operating instructions

Create these paths only when implementing the corresponding subsystem.

## Safety

- Treat every credential pasted into chat as compromised and require rotation before deployment.
- Never commit secrets, plaintext tfvars, Terraform plans/state, generated tokens, Coolify credentials, backend writer passwords, or agent tokens.
- Read secrets from environment variables, AWS Secrets Manager, existing Guild secret IDs, GitHub Actions secrets, or the macOS Keychain entry documented in the skill.
- Aiden deployments are additive by default. Stop if a plan deletes or replaces live resources or changes the workspace UUID.
- Agents may analyze, comment, and open scoped PRs; they may not approve, merge, exploit destructively, or remediate production without explicit authorization and HITL.
- The sole no-HITL merge exception is the `security-control-bootstrap` workflow documented in `talkdesk-demo-contract.md`. It may auto-merge only its own validated security-controls PR, then comment on and update the triggering application PR. It may never approve its own PR or merge an application-code PR.

## Validation

Run the checks relevant to changed files. For Aiden changes, at minimum run `tofu fmt -check -recursive`, `tofu init`, `tofu validate`, inspect a saved plan as JSON, and confirm zero deletes. For shared Guild-Solutions workflow changes, also run `make verify-workflow-stage-bindings` there.

## Git

- Do not prefix branch names with `codex`.
- Do not add Codex as a commit co-author.
- Preserve unrelated user changes and do not rewrite history without explicit approval.
