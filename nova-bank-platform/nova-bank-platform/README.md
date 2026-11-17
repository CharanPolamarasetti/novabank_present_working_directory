# Nova Bank — production-style platform on AWS (EKS Auto Mode)

Replicates a BFSI production delivery stack end-to-end on my own AWS account and adds CloudOps hardening
(secrets, security, cost, DR, observability). Built from my earlier console-built nova-bank deployment.

```
Dev → GitHub PR → merge → Jenkins (Maven → SonarQube gate → Docker → Trivy gate → ECR immutable SHA tag)
    → bot commit to GitOps repo (envs/dev) → ArgoCD auto-sync (dev) → PR to envs/prod → ArgoCD manual sync (prod)
    → EKS Auto Mode (spot NodePool) → Prometheus/Grafana → Alertmanager → Microsoft Teams
```

| Layer | Implementation |
|---|---|
| IaC | Terraform, S3 remote state + DynamoDB lock, 10 modules (`terraform/`) |
| Network | VPC, 2 AZs, public / private / isolated-data subnets, NAT, S3 gateway + ECR/STS/SecretsManager/Logs endpoints, REJECT flow logs |
| Compute | EKS Auto Mode, private nodes, spot-first custom NodePool, control-plane logs, access entries (no aws-auth) |
| Delivery | Helm (`charts/nova-service`, one chart for 3 services), ArgoCD app-of-apps + ApplicationSets |
| Secrets | Secrets Manager (KMS CMK) → External Secrets Operator → K8s Secret, IRSA, no plaintext in Git |
| Security | least-privilege IAM, KMS everywhere, ECR scan-on-push + immutable tags, GuardDuty (EKS audit), CloudTrail (validated, KMS), NetworkPolicies, non-root pods, PDB |
| Data / DR | RDS Postgres Multi-AZ, encrypted, PITR, cross-region S3 replication, timed restore drill (`docs/DR-DRILL.md`) |
| Observability | kube-prometheus-stack, failure-class alert rules, Teams via Alertmanager `msteamsv2`, CloudWatch alarms + SNS |
| Cost | Budgets (50/80/100/forecast), anomaly detection, cost-allocation tags, spot, ECR lifecycle, `destroy-after-demo.sh` |

## Layout
```
terraform/   bootstrap/ (state backend)  modules/ (network kms ecr eks secrets rds iam security observability cost dr)  envs/prod/
gitops/      charts/ envs/{dev,prod}/ platform/ argocd/ scripts/ legacy/
jenkins/     Jenkinsfile.backend  Jenkinsfile.frontend  JENKINS-HARDENING.md
docs/        RUNBOOK.md  DR-DRILL.md  COST.md  EVIDENCE.md
```

## Honest scope notes
- Applied in my own lab account; patterns mirror the TCS production stack, which I operate day to day. The TCS platform itself is owned jointly with the cloud infrastructure team.
- Lab trade-offs (documented, would change in production): single NAT, 1–3 replicas, RDS `deletion_protection=false`, DB TLS enforcement off until the JDBC URL carries `sslmode=require`, single shared DB user for both services.
- Egress NetworkPolicies are not applied (ingress default-deny only).
