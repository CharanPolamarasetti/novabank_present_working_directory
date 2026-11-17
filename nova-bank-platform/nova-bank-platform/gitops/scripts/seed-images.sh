#!/usr/bin/env bash
# One-time: copy your existing Docker Hub images into the new (immutable, scanned) ECR repos with a version tag,
# and point dev+prod values at it. Afterwards Jenkins owns the tags (git SHA).
# Usage: ./scripts/seed-images.sh <dockerhub-user> <source-tag> <new-tag>      e.g.  charan 1 v1
set -euo pipefail
cd "$(dirname "$0")/.."
HUB="${1:?dockerhub user}"; SRC="${2:?source tag}"; NEW="${3:?new tag}"
REG=$(terraform -chdir=../terraform/envs/prod output -raw ecr_registry)
REGION=ap-south-1
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin "$REG"
for svc in account-service customer-service frontend; do
  docker pull "$HUB/$svc:$SRC"
  docker tag  "$HUB/$svc:$SRC" "$REG/novabank/$svc:$NEW"
  docker push "$REG/novabank/$svc:$NEW"
  for env in dev prod; do yq -i ".image.tag = \"$NEW\"" "envs/$env/$svc.yaml"; done
done
echo "Done. Commit + push envs/*, then check scan results: aws ecr describe-image-scan-findings --repository-name novabank/frontend --image-id imageTag=$NEW"
