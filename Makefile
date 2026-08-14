.PHONY: init validate app-test policy-test terraform-validate workflow-lint

init:
	tofu -chdir=infra/aws init -backend=false
	tofu -chdir=infra/grafana init -backend=false
	tofu -chdir=aiden init -backend=false
	npm ci --prefix app

validate: app-test policy-test terraform-validate workflow-lint
	shellcheck scripts/postdeploy/*.sh

app-test:
	npm run typecheck --prefix app
	npm test --prefix app -- --run
	npm run build --prefix app
	npm audit --prefix app --omit=dev

policy-test:
	opa test policies -v

terraform-validate:
	tofu fmt -check -recursive
	tofu -chdir=infra/aws validate
	tofu -chdir=infra/grafana validate
	tofu -chdir=aiden validate

workflow-lint:
	go run github.com/rhysd/actionlint/cmd/actionlint@v1.7.7 .github/workflows/*.yml demo/control-templates/security-gate.yml
