# Architecture Overview

## System Diagram

```
                         ┌──────────────────────────────────────────┐
                         │                  AWS Cloud                │
                         │                                          │
  Browser / curl         │   ┌─────────────────────────────────┐   │
       │                 │   │    Application Load Balancer     │   │
       │ HTTP :80        │   │    (joel-hello-alb)              │   │
       └────────────────►│   │    Internet-facing, port 80      │   │
                         │   └────────────────┬────────────────┘   │
                         │                    │ HTTP :8000          │
                         │   ┌────────────────▼────────────────┐   │
                         │   │   EC2 Instance (t2.micro)        │   │
                         │   │   Amazon Linux 2023              │   │
                         │   │   FastAPI via uvicorn :8000      │   │
                         │   └────────────────┬────────────────┘   │
                         │                    │ HTTPS               │
                         │   ┌────────────────▼────────────────┐   │
                         │   │   API Gateway v2 (HTTP API)      │   │
                         │   │   GET /                          │   │
                         │   └────────────────┬────────────────┘   │
                         │                    │ invoke              │
                         │   ┌────────────────▼────────────────┐   │
                         │   │   Lambda Function (Python 3.12)  │   │
                         │   │   joel-hello-hello-world         │   │
                         │   └─────────────────────────────────┘   │
                         │                                          │
                         └──────────────────────────────────────────┘
```

## Request Flow

1. **Client** sends `GET http://<alb-dns>/` on port 80
2. **ALB** receives the request and forwards it (HTTP) to the EC2 target on port 8000
3. **FastAPI** (running on EC2) handles the request in `root()`
4. FastAPI makes an async HTTP GET to the **API Gateway** URL (stored in `API_GATEWAY_URL` env var)
5. **API Gateway** routes `GET /` to the integrated **Lambda** function
6. **Lambda** returns `{"message": "Hello, World!"}`
7. FastAPI renders the message into an HTML page and returns it to the ALB
8. ALB returns the HTML response to the client with **HTTP 200**

## Components

| Component | Service | Purpose |
|-----------|---------|---------|
| Load Balancer | AWS ALB | Internet entry point on port 80 |
| Web Server | EC2 t2.micro | Hosts the FastAPI application |
| Web Framework | FastAPI + uvicorn | Serves HTTP responses |
| API Backend | API Gateway v2 | Routes HTTP requests to Lambda |
| Compute | Lambda (Python 3.12) | Business logic — returns Hello World |
| IaC | Terraform ≥ 1.3 | Provision and manage all resources |
| CI/CD | GitHub Actions | Auto-deploy on push to `main` |

## Security Design

```
Internet ──► ALB SG (port 80 open)
                    │
                    ▼
             EC2 SG (port 8000 only from ALB SG)
```

- **ALB Security Group** — allows inbound TCP 80 from `0.0.0.0/0`, all egress
- **EC2 Security Group** — allows inbound TCP 8000 **only** from the ALB security group (not from the internet directly); all egress
- No SSH port is exposed; EC2 is manageable via **AWS Systems Manager (SSM)**

## IAM Roles

| Role | Principal | Policies |
|------|-----------|----------|
| `joel-hello-lambda-exec` | `lambda.amazonaws.com` | `AWSLambdaBasicExecutionRole` |
| `joel-hello-ec2-role` | `ec2.amazonaws.com` | `AmazonSSMManagedInstanceCore` |

## Networking

All resources use the **AWS default VPC** and its default subnets across availability zones. The ALB is spread across all default subnets for high-availability; the EC2 instance is placed in the first available subnet.
