# Project Documentation

This project deploys a **Hello World HTTP app** on AWS using FastAPI, EC2, ALB, API Gateway, and Lambda — all managed by Terraform with CI/CD via GitHub Actions.

## Document Index

### Architecture
- [architecture.md](./architecture.md) — Full system architecture, data flow, and component relationships

### Application Code
| File | Doc |
|------|-----|
| `src/handler.py` | [app/handler.md](./app/handler.md) |
| `app/main.py` | [app/fastapi.md](./app/fastapi.md) |
| `app/requirements.txt` | [app/requirements.md](./app/requirements.md) |

### Infrastructure (Terraform)
| File | Doc |
|------|-----|
| `terraform/main.tf` | [terraform/main.md](./terraform/main.md) |
| `terraform/ec2_alb.tf` | [terraform/ec2_alb.md](./terraform/ec2_alb.md) |
| `terraform/variables.tf` | [terraform/variables.md](./terraform/variables.md) |
| `terraform/outputs.tf` | [terraform/outputs.md](./terraform/outputs.md) |
| `terraform/userdata.sh.tpl` | [terraform/userdata.md](./terraform/userdata.md) |

### CI/CD
| File | Doc |
|------|-----|
| `.github/workflows/deploy.yml` | [cicd.md](./cicd.md) |

## Project Structure

```
joel/
├── app/
│   ├── main.py               # FastAPI HTTP app served by EC2
│   └── requirements.txt      # Python dependencies
├── src/
│   └── handler.py            # Lambda function
├── terraform/
│   ├── main.tf               # Lambda + API Gateway resources
│   ├── ec2_alb.tf            # EC2 + ALB + Security Groups
│   ├── variables.tf          # Input variables
│   ├── outputs.tf            # Output values (URLs)
│   └── userdata.sh.tpl       # EC2 bootstrap script
├── .github/
│   └── workflows/
│       └── deploy.yml        # GitHub Actions CI/CD
├── .gitignore
└── README.md
```
