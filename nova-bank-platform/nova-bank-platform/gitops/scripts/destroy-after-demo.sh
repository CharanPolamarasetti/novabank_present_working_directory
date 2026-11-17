#!/usr/bin/env bash
# Cost control: tear everything down cleanly. ALBs/volumes created by Kubernetes controllers are NOT in
# Terraform state, so they must be removed first or the VPC destroy hangs and keeps billing.
set -euo pipefail
echo ">> Stopping ArgoCD reconciliation and deleting Kubernetes-created AWS resources"
kubectl -n argocd delete applicationset --all --ignore-not-found || true
kubectl -n argocd delete application root --ignore-not-found || true
kubectl delete ingress -A --all --ignore-not-found --wait=true || true
kubectl delete pvc -A --all --ignore-not-found --wait=true || true
echo ">> Waiting 90s for ALB + EBS cleanup"; sleep 90
echo ">> Remaining load balancers (should be none):"
aws elbv2 describe-load-balancers --query 'LoadBalancers[].LoadBalancerName' --output text || true
read -rp "Run terraform destroy now? (yes/no) " a
[ "$a" = "yes" ] && terraform -chdir=../terraform/envs/prod destroy
echo "State bucket (bootstrap) is kept on purpose. Verify billing: aws ce get-cost-and-usage ... or the Budgets console."
