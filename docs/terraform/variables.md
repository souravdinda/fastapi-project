# `terraform/variables.tf` — Input Variables

**Location:** `terraform/variables.tf`  
**Role:** Centralises all configurable parameters so the infrastructure can be customised without modifying any resource files

---

## Variables Reference

### `aws_region`

```hcl
variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}
```

The AWS region where all resources are created. Defaults to `us-east-1` (N. Virginia). To deploy to another region:

```bash
terraform apply -var="aws_region=eu-west-1"
```

---

### `aws_profile`

```hcl
variable "aws_profile" {
  description = "AWS CLI named profile to use for authentication"
  type        = string
  default     = "joel"
}
```

The AWS CLI **named profile** used by the `aws` Terraform provider. This maps to an entry in `~/.aws/credentials` or `~/.aws/config`.

**Local deployment:** Uses the `joel` profile by default — no extra flags needed.

**CI/CD:** The GitHub Actions workflow overrides this to an empty string (`-var="aws_profile="`), so the provider falls back to environment variable credentials (`AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`) injected by the pipeline.

```bash
# Override profile
terraform apply -var="aws_profile=my-other-profile"

# Disable named profile (use env vars)
terraform apply -var="aws_profile="
```

---

### `project_name`

```hcl
variable "project_name" {
  description = "Prefix for all resource names"
  type        = string
  default     = "joel-hello"
}
```

A string prefix applied to every AWS resource name. This prevents naming collisions when multiple deployments exist in the same account and makes it easy to identify related resources in the console.

Examples of generated names:
| Resource | Generated Name |
|----------|---------------|
| Lambda | `joel-hello-hello-world` |
| API Gateway | `joel-hello-api` |
| ALB | `joel-hello-alb` |
| Target Group | `joel-hello-tg` |
| IAM Role (Lambda) | `joel-hello-lambda-exec` |
| IAM Role (EC2) | `joel-hello-ec2-role` |

---

### `ec2_instance_type`

```hcl
variable "ec2_instance_type" {
  description = "EC2 instance type for the FastAPI server"
  type        = string
  default     = "t2.micro"
}
```

The EC2 instance family and size. Defaults to `t2.micro`:
- **1 vCPU** — fits within the AWS account's 1-vCPU running instance limit
- **1 GiB RAM** — sufficient for FastAPI + uvicorn at low traffic
- **Free-tier eligible** (750 hours/month for new accounts)

To scale up: `terraform apply -var="ec2_instance_type=t3.small"`

---

### `tags`

```hcl
variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default = {
    Project     = "hello-world"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}
```

A map of tags applied to every taggable resource. Tags serve multiple purposes:
- **Cost allocation** — filter costs by project in AWS Cost Explorer
- **Identification** — distinguish resources from other projects
- **Automation** — targeting resources in scripts or policies by tag

The `ManagedBy = "terraform"` tag signals that resources should not be modified manually.
