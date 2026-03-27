# Hello World – AWS API Gateway + Lambda

A minimal "Hello World" HTTP app deployed on AWS using **API Gateway v2 (HTTP API)** and **Lambda (Python 3.12)**, with infrastructure managed by **Terraform** and CI/CD via **GitHub Actions**.

State is stored in an **S3 remote backend** (`demo1bucket90`).

---

## Project Structure

```
.
├── src/
│   └── handler.py            # Lambda function
├── terraform/
│   ├── main.tf               # API Gateway + Lambda resources
│   ├── variables.tf          # Input variables (aws_profile, region, …)
│   └── outputs.tf            # API URL output
├── .github/
│   └── workflows/
│       └── deploy.yml        # CI/CD pipeline
└── README.md
```

---

## Local Deployment

### Prerequisites

| Tool      | Version |
|-----------|---------|
| Terraform | ≥ 1.3   |
| AWS CLI   | ≥ 2     |
| Python    | 3.12    |

Make sure you have an AWS CLI profile named **`joel`** configured:

```bash
aws configure --profile joel
# or edit ~/.aws/credentials / ~/.aws/config directly
```

### Deploy

```bash
cd terraform
terraform init
terraform apply          # uses the 'joel' profile by default
```

To override the profile or region at deploy time:

```bash
terraform apply -var="aws_profile=other-profile" -var="aws_region=eu-west-1"
```

### Test

```bash
curl "$(terraform output -raw api_url)"
# → {"message": "Hello, World!"}
```

### Destroy

```bash
terraform destroy
```

---

## CI/CD (GitHub Actions)

On every push to `main`, the pipeline:

1. Configures AWS credentials from **repository secrets**
2. Runs `terraform init → validate → plan → apply`
3. Prints the deployed API URL

### Required Secrets

| Secret | Description |
|--------|-------------|
| `AWS_ACCESS_KEY_ID` | IAM access key ID |
| `AWS_SECRET_ACCESS_KEY` | IAM secret access key |

> **Note:** CI uses environment credentials directly (no named profile needed). The `aws_profile` variable is set to an empty string in the pipeline.

---

## API

| Method | Path | Response |
|--------|------|----------|
| `GET`  | `/`  | `{"message": "Hello, World!"}` |
