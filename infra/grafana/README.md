# Grafana provisioning

This root reuses the existing ObserveNow data sources and creates one demo folder, dashboard, and evaluating alert rule. It intentionally creates no contact points or notification policies.

Retrieve the dedicated provisioner token without printing it:

```bash
export TF_VAR_grafana_auth="$(security find-generic-password \
  -a talkdesk-coolify \
  -s com.stackgen.talkdesk-coolify.grafana \
  -w)"
tofu init
tofu fmt -check -recursive
tofu validate
tofu plan -out=tfplan
unset TF_VAR_grafana_auth
```

The token is time-limited. Replace it if expired and rotate any administrator or backend credentials previously pasted into chat.
