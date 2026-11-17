# Runbook — from zero to running (≈ 90 min, most of it waiting on AWS)

Prereqs on your laptop: terraform, awscli (configured), kubectl, helm, yq, docker, git.

## 0. Static checks (5 min) — I could not run these in my sandbox, so run them first
```bash
cd terraform && terraform fmt -recursive -check
cd envs/prod && terraform init -backend=false && terraform validate
cd ../../../gitops && for e in dev prod; do for s in account-service customer-service frontend; do
  helm lint charts/nova-service -f envs/$e/$s.yaml && helm template $s charts/nova-service -f envs/$e/$s.yaml >/dev/null; done; done
helm template x charts/postgres-dev >/dev/null && helm template x charts/db-init >/dev/null
```
Fix anything these report before spending AWS credits (paste errors to me and I'll patch).

## 1. State backend (once)
```bash
cd terraform/bootstrap && terraform init && terraform apply
terraform output -raw backend_hcl > ../envs/prod/backend.hcl
```

## 2. Platform
```bash
cd ../envs/prod
cp terraform.tfvars.example terraform.tfvars    # set admin_ip_cidr, admin_principal_arns
terraform init -backend-config=backend.hcl
terraform plan -out tf.plan                      # REVIEW: ~90 resources
terraform apply tf.plan                          # EKS + RDS Multi-AZ ≈ 25–30 min
$(terraform output -raw kubeconfig_cmd)
kubectl get nodes                                # may be empty until first pods (Auto Mode)
```
Confirm the SNS email subscription and the Budgets email.

## 3. Teams webhook (Teams → Workflows → "Post to a channel when a webhook request is received")
```bash
aws secretsmanager put-secret-value --secret-id novabank/prod/teams-webhook --secret-string '<url>'
```

## 4. GitOps repo
Copy `gitops/` into your GitOps repo (`legacy/` keeps the original manifests), push, then:
```bash
cd gitops && ./scripts/seed-images.sh <dockerhub-user> <src-tag> v1     # copies images into ECR
git add -A && git commit -m "seed image tags" && git push
./scripts/bootstrap.sh https://github.com/CharanPolamarasetti/nova-bank-GitOps.git
```
ArgoCD sync order: external-secrets → platform-config → kube-prometheus-stack → monitoring-config → postgres-dev / db-init → services.
Prod is manual: ArgoCD UI → `db-init-prod` Sync, then each `*-prod` app Sync.

## 5. Verify (take screenshots → `docs/EVIDENCE.md`)
```bash
kubectl get app -n argocd                          # all Synced/Healthy
kubectl get externalsecret -A                      # all SecretSynced
kubectl get pods -n novabank-prod -o wide          # spread over 2 AZs, on spot nodes
kubectl get ingress -n novabank-prod               # ALB hostname → open /dashboard.html
kubectl get nodes -L karpenter.sh/capacity-type
```

## 6. CI
Point the Jenkins jobs at `jenkins/Jenkinsfile.*`; apply `jenkins/JENKINS-HARDENING.md`; replace `<ACCOUNT_ID>`.
Promotion: copy the tested `image.tag` from `envs/dev/<svc>.yaml` into `envs/prod/<svc>.yaml` via PR → approve → Sync prod.

## 7. Known gotchas
- No `kubectl top`/HPA data? Install metrics-server (`helm install metrics-server`) if Auto Mode doesn't provide it.
- ESO chart/API: pinned to `2.*` (`external-secrets.io/v1`). If `helm template` complains, use `v1beta1` and chart `0.x`.
- Pin `kube-prometheus-stack` (`targetRevision: "*"`) to the resolved version after the first sync.
- Auto Mode NodePool labels differ by release: `kubectl get nodepool apps -o yaml` shows validation errors if so.
- GuardDuty "detector already exists": `terraform import module.security.aws_guardduty_detector.this[0] <detector-id>` or set `enable_guardduty=false`.
- Cost-allocation tags: activate Project/Env/Owner in Billing console ~24h after first apply.
- RDS name collisions after destroy/apply: wait ~5 min or change `name`.

## 8. Teardown
`./gitops/scripts/destroy-after-demo.sh` (removes ALB/EBS first), then `terraform destroy`. Keep `bootstrap/` (pennies).
