# Jenkins hardening checklist (do once)

1. **Replace AdministratorAccess** on the Jenkins EC2 role with only:
   `{"Effect":"Allow","Action":"sts:AssumeRole","Resource":"arn:aws:iam::<ACCOUNT_ID>:role/novabank-prod-jenkins-ci"}`
   The pipeline assumes `novabank-prod-jenkins-ci` (ECR push on `novabank/*` only) for the push stage.
2. **IMDSv2 required**: `aws ec2 modify-instance-metadata-options --instance-id <id> --http-tokens required --http-put-response-hop-limit 1`
3. **Security groups**: 8080 (Jenkins) and 9000 (SonarQube) from `<your-ip>/32` only; SSH 22 from `<your-ip>/32` only.
4. **Credentials**: GitHub PAT stored as Jenkins credential `github-gitops` (fine-grained, contents:write on the GitOps repo only). No secrets in Jenkinsfiles.
5. **Controller executes nothing**: set executors to 0 on the built-in node once an agent exists (lab: single node, documented trade-off).
6. **Backup**: `tar czf jenkins-home-$(date +%F).tgz /var/lib/jenkins --exclude=workspace` to S3 (or EBS snapshot of the volume) weekly.
7. **Branch protection** on `main` of the GitOps repo: PR + 1 approval for `envs/prod/**` (CODEOWNERS); Jenkins bot may push only to `envs/dev/**` (enforced by convention + CODEOWNERS).
8. **ECR**: tags immutable, scan-on-push, lifecycle policy (Terraform).
