# rag-platform-infra

Terraform + GitHub Actions for the **AWS resources** behind the RAG system. The application code lives in a separate repo (`rag-app`).

| Layer | Resources | Where |
|---|---|---|
| Bootstrap (once, local) | Terraform state bucket, GitHub OIDC provider, plan/apply IAM roles for this repo | `bootstrap/` |
| Platform (pipeline) | S3 docs bucket, S3 Vectors bucket + index, Bedrock Knowledge Base + data source, KB service role, SSM parameters, IAM roles for the app repo's pipelines | `terraform/` |

The app repo finds the platform through SSM parameters under `/rag-platform/<env>/`
(`knowledge-base-id`, `knowledge-base-arn`, `data-source-id`, `docs-bucket`), so the two repos never share state.

## Pipelines

| Workflow | Trigger | What it does | AWS role |
|---|---|---|---|
| `terraform-plan` | Pull request touching `terraform/**` | fmt check, init, validate, plan; posts the plan as a PR comment | `rag-platform-infra-plan` (read-only) |
| `terraform-apply` | Push to `main` | plan then apply, behind the `production` environment approval | `rag-platform-infra-apply` |

Authentication is GitHub OIDC, so there are no long-lived AWS keys in GitHub. The apply role can only be assumed by jobs running in the `production` environment of this repo.

## One-time setup

**1. Bootstrap (local, admin credentials)**
```bash
cd bootstrap
terraform init
terraform apply        # values come from bootstrap/terraform.tfvars
```
GitHub's OIDC subject contains numeric IDs (`repo:<owner>@<owner id>/<repo>@<repo id>:pull_request`), so
the trust policies are built from `github_owner_id` and `infra_repo_id` in `terraform.tfvars`.
If you fork this setup, find your own IDs with `curl -s https://api.github.com/repos/<owner>/<repo>`
(the repository `id`, and `owner.id`), and see the real subject in CloudTrail if a role refuses to assume.
Note the outputs: `tf_state_bucket`, `aws_plan_role_arn`, `aws_apply_role_arn`.

**2. Create the GitHub repo and set variables**
```bash
gh repo create <org>/rag-platform-infra --private --source=. --push
gh variable set AWS_REGION        --body us-east-1
gh variable set TF_STATE_BUCKET   --body <tf_state_bucket>
gh variable set AWS_PLAN_ROLE_ARN  --body <aws_plan_role_arn>
gh variable set AWS_APPLY_ROLE_ARN --body <aws_apply_role_arn>
```
In **Settings → Environments**, create `production` and add yourself as a required reviewer.

**3. Enable Bedrock model access** (console, region `us-east-1`): Titan Text Embeddings V2, and the Claude model the app will use.

**4. Deploy:** open a PR that touches `terraform/`, review the plan comment, merge, approve the `production` deployment.

**5. Hand off to the app repo:** run `terraform output` (shown at the end of the apply job) and set these in the `rag-app` repo:
```bash
gh variable set AWS_PLAN_ROLE_ARN   --repo <org>/rag-app --body <app_plan_role_arn>
gh variable set AWS_DEPLOY_ROLE_ARN --repo <org>/rag-app --body <app_deploy_role_arn>
gh variable set TF_STATE_BUCKET     --repo <org>/rag-app --body <tf_state_bucket>
gh variable set AWS_REGION          --repo <org>/rag-app --body us-east-1
```

## Local runs

```bash
cd terraform
terraform init \
  -backend-config="bucket=<tf_state_bucket>" \
  -backend-config="key=rag-platform-infra/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="use_lockfile=true"
terraform plan -var-file=envs/dev.tfvars -var github_org=<org> -var state_bucket_name=<tf_state_bucket>
```

## Notes and choices

- **Provider version:** S3 Vectors integration with Bedrock Knowledge Bases needs `hashicorp/aws` 6.27.0 or newer.
- **State locking:** uses S3 native locking (`use_lockfile`, Terraform 1.10+), so there is no DynamoDB table.
- **Apply role is `AdministratorAccess`.** That is deliberately simple for a demo, gated by the OIDC subject and the approval environment. Replace it with a scoped policy before real use.
- **Cost:** no always-on compute. S3, S3 Vectors and Titan embeddings are billed per use, which is cents at demo scale.
- **Teardown:** the app repo first (`terraform destroy` in its pipeline or locally), then this repo's `terraform/`, then `bootstrap/`. `data_deletion_policy = "RETAIN"` on the data source keeps destroy from failing on vector cleanup; the vector index is deleted with its bucket.
