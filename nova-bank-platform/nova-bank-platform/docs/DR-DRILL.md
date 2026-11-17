# DR drill — fill the table, screenshot each step (this is the portfolio's DR evidence)

Define targets first: **RTO 30 min, RPO 5 min** (RDS PITR granularity).

| # | Scenario | Command | Start | End | Measured | Verdict |
|---|---|---|---|---|---|---|
| A | AZ/instance failure (Multi-AZ failover) | `aws rds reboot-db-instance --db-instance-identifier novabank-prod-postgres --force-failover` | | login works again | RTO = end−start | |
| B | Data corruption → point-in-time restore | see below | | restored DB verified | RTO, RPO | |
| C | Region-level backup availability | upload to primary bucket, wait for DR copy | | object visible in DR bucket | replication lag | |
| D | Total cluster loss | `terraform destroy` (cluster only) → `apply` → `bootstrap.sh` | | app healthy | rebuild RTO | |

## A. Multi-AZ failover
1. Terminal 1: `while true; do curl -s -o /dev/null -w "%{http_code} $(date +%T)\n" http://<ALB>/dashboard.html; sleep 2; done`
2. Terminal 2: record `date +%T`, run the failover command, watch `aws rds describe-events --duration 15 --source-type db-instance`.
3. Log in through the UI (JWT flow hits the DB). Expect 60–120 s of DB errors, apps self-heal via JDBC reconnect.

## B. Point-in-time restore
```bash
T0=$(date +%s)
aws rds restore-db-instance-to-point-in-time --source-db-instance-identifier novabank-prod-postgres \
  --target-db-instance-identifier novabank-restore --use-latest-restorable-time \
  --db-subnet-group-name novabank-prod-db --vpc-security-group-ids <rds-sg-id> --no-multi-az --db-instance-class db.t4g.micro
aws rds wait db-instance-available --db-instance-identifier novabank-restore
echo "restore minutes: $(( ($(date +%s)-T0)/60 ))"
aws rds describe-db-instances --db-instance-identifier novabank-restore --query 'DBInstances[0].LatestRestorableTime'
# verify: kubectl run psql --rm -it --image=postgres:16-alpine -n novabank-prod -- psql -h <restore-endpoint> -U novabank -d customerdb -c '\dt'
aws rds delete-db-instance --db-instance-identifier novabank-restore --skip-final-snapshot   # stop billing
```
RPO = now − `LatestRestorableTime` (≈ ≤5 min).

## C. Cross-region replication
```bash
date +%T; echo drill > f.txt; aws s3 cp f.txt s3://<primary_bucket>/f.txt
until aws s3api head-object --bucket <dr_bucket> --key f.txt --region ap-southeast-1 2>/dev/null; do sleep 5; done; date +%T
```

## D. Rebuild
`terraform destroy -target=module.eks` is not safe with dependents; use full `destroy-after-demo.sh` then re-run runbook steps 2–4. Record wall-clock: this is your "infrastructure fully reproducible from Git in N minutes" number.

## Write-up template (README / portfolio)
> Defined RTO 30 min / RPO 5 min. Multi-AZ failover measured **X s**; PITR restore measured **Y min** with RPO **Z min**; cross-region S3 replication lag **W s**; full platform rebuild from Git **V min**.
