#!/usr/bin/env bash
# Usage: ./scripts/bootstrap.sh https://github.com/<you>/nova-bank-GitOps.git
# Prereqs: terraform applied, kubectl context pointing at the cluster, helm installed.
set -euo pipefail
cd "$(dirname "$0")/.."
REPO_URL="${1:?usage: bootstrap.sh <gitops-repo-https-url>}"
TF=../terraform/envs/prod

ESO_ROLE=$(terraform -chdir="$TF" output -raw eso_role_arn)
REG=$(terraform -chdir="$TF" output -raw ecr_registry)

echo ">> Rendering placeholders (ESO role, ECR registry, repo URL)"
grep -rl -E '__(ESO_ROLE_ARN|ECR_REGISTRY|GITOPS_REPO_URL)__' --include='*.yaml' . | grep -v '^./legacy/' | \
  xargs -r sed -i "s|__ESO_ROLE_ARN__|${ESO_ROLE}|g;s|__ECR_REGISTRY__|${REG}|g;s|__GITOPS_REPO_URL__|${REPO_URL}|g"

echo ">> Commit + push the rendered files, then press Enter (ArgoCD reads from Git)"
echo "   git add -A && git commit -m 'render env values' && git push origin main"
read -r _

echo ">> Installing ArgoCD"
helm repo add argo https://argoproj.github.io/argo-helm >/dev/null
helm repo update >/dev/null
helm upgrade --install argocd argo/argo-cd -n argocd --create-namespace --wait --timeout 10m

echo ">> Applying root app (app-of-apps)"
kubectl apply -f argocd/root.yaml

echo
echo "ArgoCD admin password:"
echo "  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo"
echo "UI:  kubectl -n argocd port-forward svc/argocd-server 8080:443   -> https://localhost:8080"
echo "NOTE: set the Teams webhook once:"
echo "  aws secretsmanager put-secret-value --secret-id novabank/prod/teams-webhook --secret-string '<workflow-webhook-url>'"
