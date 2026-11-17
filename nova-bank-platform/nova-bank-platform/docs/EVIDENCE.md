# Evidence checklist (screenshots/outputs for the portfolio; redact account IDs)

- [ ] `terraform plan` summary + `apply` complete, module tree
- [ ] ArgoCD app-of-apps: all Synced/Healthy; one app's resource tree
- [ ] ALB URL serving `/dashboard.html`; login works
- [ ] `kubectl get externalsecret -A` (SecretSynced) + Secrets Manager console (KMS key, no plaintext in Git: `git grep -i password`)
- [ ] Pods on spot nodes across 2 AZs (`kubectl get nodes -L karpenter.sh/capacity-type,topology.kubernetes.io/zone`)
- [ ] ECR: immutable tags, scan findings, lifecycle policy
- [ ] Jenkins pipeline green: Sonar quality gate, Trivy gate, push, bot commit
- [ ] Failed Trivy gate (optional: build with a vulnerable base) — shows the control works
- [ ] NetworkPolicy proof: `kubectl exec` from a random pod to account-service times out; from frontend succeeds
- [ ] Grafana dashboard + Teams alert received (kill a pod with `kubectl set resources` to force OOM)
- [ ] CloudWatch alarms, CloudTrail trail, GuardDuty enabled
- [ ] Budgets alert configured + cost explorer by `Project` tag
- [ ] DR drill table filled with real numbers (`DR-DRILL.md`)
- [ ] Teardown output + final $ spent
