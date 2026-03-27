# `.github/workflows/deploy.yml` — CI/CD Pipeline

**Location:** `.github/workflows/deploy.yml`  
**Role:** Automatically deploys the full infrastructure to AWS on every push to `main`

---

## Purpose

This is a **GitHub Actions** workflow that automates the Terraform deployment. Every merge to `main` triggers the pipeline, which runs `terraform init → validate → plan → apply` and prints the deployed API URL.

---

## Trigger Events

```yaml
on:
  push:
    branches: [main]
  workflow_dispatch:
```

- **`push` to `main`** — automatic deploy on every merge/push to the main branch
- **`workflow_dispatch`** — allows manual triggering from the GitHub Actions UI without a code push (useful for re-deploying after manual AWS changes)

---

## Environment Variables

```yaml
env:
  AWS_REGION: us-east-1
  TF_WORKING_DIR: terraform
```

- **`AWS_REGION`** — used by the AWS credentials action and passed to Terraform
- **`TF_WORKING_DIR`** — all Terraform steps use `working-directory: terraform` so commands run in the right folder without `cd`

---

## Job: `deploy`

```yaml
jobs:
  deploy:
    name: Terraform Deploy
    runs-on: ubuntu-latest
```

Runs on GitHub's hosted `ubuntu-latest` runner (free for public repos).

---

## Steps

### 1. Checkout

```yaml
- name: Checkout code
  uses: actions/checkout@v4
```

Clones the repository into the runner workspace. `@v4` is the current major version of the official GitHub checkout action.

---

### 2. Configure AWS Credentials

```yaml
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
    aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    aws-region: ${{ env.AWS_REGION }}
```

Sets up AWS authentication via **repository secrets** rather than a named profile. The action:
1. Exports `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` as environment variables
2. Sets `AWS_DEFAULT_REGION`
3. Masks the credentials in all log output

**Required secrets** (set in GitHub → Repo Settings → Secrets → Actions):
| Secret | Value |
|--------|-------|
| `AWS_ACCESS_KEY_ID` | IAM user access key ID |
| `AWS_SECRET_ACCESS_KEY` | IAM user secret access key |

The IAM user should have permissions to manage Lambda, API Gateway, EC2, ALB, IAM, and VPC resources.

---

### 3. Setup Terraform

```yaml
- name: Setup Terraform
  uses: hashicorp/setup-terraform@v3
  with:
    terraform_version: "1.10.5"
```

Installs the specified Terraform version on the runner. Pinning to `"1.10.5"` ensures the pipeline uses a known-good version supporting S3 native state locking.

---

### 4. Terraform Init

```yaml
- name: Terraform Init
  working-directory: ${{ env.TF_WORKING_DIR }}
  run: terraform init
```

Downloads the AWS and archive providers into `.terraform/`. This must run before any other Terraform commands. The providers are cached by the runner for performance.

---

### 5. Terraform Validate

```yaml
- name: Terraform Validate
  working-directory: ${{ env.TF_WORKING_DIR }}
  run: terraform validate
```

Performs static validation of the configuration files — checks for syntax errors, invalid references, and type mismatches. **Does not** make any API calls. Fails fast before attempting a plan if config is broken.

---

### 6. Terraform Plan

```yaml
- name: Terraform Plan
  working-directory: ${{ env.TF_WORKING_DIR }}
  run: |
    terraform plan \
      -var="aws_profile=" \
      -out=tfplan
```

Computes the difference between current state and desired state.

Key details:
- **`-var="aws_profile="`** — overrides the `aws_profile` variable to an empty string, forcing the AWS provider to use the environment variable credentials (set in step 2) instead of looking for a named profile that doesn't exist on the runner
- **`-out=tfplan`** — saves the plan to a binary file so the subsequent `apply` executes exactly what was planned (prevents TOCTOU race conditions)
- The plan output shows what will be created, changed, or destroyed — visible in the GitHub Actions log

---

### 7. Terraform Apply

```yaml
- name: Terraform Apply
  if: github.ref == 'refs/heads/main'
  run: terraform apply -auto-approve tfplan
```

Applies the saved plan:
- **`if: github.ref == 'refs/heads/main'`** — only applies on the `main` branch; feature branches only plan (useful if the workflow is extended to run on PRs)
- **`-auto-approve`** — skips the interactive confirmation prompt (required for unattended CI)
- **`tfplan`** — uses the exact plan file from the previous step

---

### 8. Output API URL

```yaml
- name: Output API URL
  working-directory: ${{ env.TF_WORKING_DIR }}
  run: terraform output api_url
```

Prints the deployed API Gateway URL at the end of the run. Useful for quick verification in the Actions log that the deploy succeeded and the right URL is live.

---

## Extending the Pipeline

Common additions:
- **Pull Request plan comments** — use `terraform-github-actions` to post plan output as a PR comment
- **Separate plan/apply jobs** — plan on PR, apply only on merge to `main`
- **Remote state** — use an S3 backend + DynamoDB lock table so state is shared across team members and CI runs
- **Slack notification** — use `slackapi/slack-github-action` to notify on success/failure

---

## Destroy Workflow (`destroy.yml`)

The repository also includes a manual workflow to tear down the infrastructure.

**Trigger:** `workflow_dispatch` (Manual via GitHub Actions UI)

It requires you to type "DESTROY" in an input prompt before running to prevent accidental clicks. It authenticates with the same AWS credentials and runs `terraform destroy -auto-approve`.
