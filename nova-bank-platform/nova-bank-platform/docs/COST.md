# Cost plan (budget ≈ $90 credit)

| Item | Approx. per day running | Lever |
|---|---|---|
| EKS control plane | $2.40 | destroy when idle |
| Auto Mode management fee + nodes (2–4 small spot) | $1.5–3 | spot NodePool, consolidation, cpu limit 12 |
| NAT gateway (1) + 4 interface endpoints × 2 AZ | $1.1 + ~$1.9 | single NAT; endpoints removable via `enable_interface_endpoints=false` |
| RDS t4g.micro Multi-AZ | ~$1.0 | set `rds_multi_az=false` outside the DR demo |
| ALB | $0.6 | destroy |
| GuardDuty / CloudTrail / logs | <$0.5 | 14-day retention |

**≈ $9–11/day while up → keep it up ≤ 5–6 days total.** Plan: build day, test 1–2 days, DR drill + screenshots 1 day, destroy.
Guardrails in Terraform: Budget $60 (alerts 50/80/100% + forecast), anomaly detection ≥ $5, cost-allocation tags (Project/Env/Owner).
Tip: do not leave the cluster up overnight during build; `destroy-after-demo.sh` then re-apply costs ~40 min.
