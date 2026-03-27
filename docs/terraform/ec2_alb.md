# `terraform/ec2_alb.tf` — EC2, ALB, and Security Groups

**Location:** `terraform/ec2_alb.tf`  
**Role:** Provisions the HTTP frontend infrastructure — EC2 instance running FastAPI behind an Application Load Balancer

---

## Purpose

This file defines all resources needed to serve the FastAPI app publicly on port 80:
- Data sources: VPC, subnets, AMI
- Security groups for ALB and EC2
- Application Load Balancer, target group, and listener
- IAM role for the EC2 instance
- EC2 instance with bootstrap user data
- Target group attachment

---

## Data Sources

### Default VPC

```hcl
data "aws_vpc" "default" {
  default = true
}
```

Looks up the default VPC in the AWS account. Using the default VPC avoids the need to create a custom VPC, simplifying the setup for a demo project.

### Default Subnets

```hcl
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}
```

Retrieves **all subnets** in the default VPC. The ALB uses all of them (multi-AZ), while the EC2 instance uses only the first one.

### Latest Amazon Linux 2023 AMI

```hcl
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
```

Dynamically resolves the **latest** Amazon Linux 2023 x86_64 HVM AMI. Using `most_recent = true` ensures the EC2 instance always uses a patched, up-to-date base image. `owners = ["amazon"]` prevents picking up community AMIs with similar names.

---

## Security Groups

### ALB Security Group

```hcl
resource "aws_security_group" "alb" {
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]   # open to internet
  }
  egress { ... all traffic ... }
}
```

Public-facing. Allows all inbound HTTP on port 80 from the internet. Egress is unrestricted so the ALB can health-check and forward requests to EC2.

### EC2 Security Group

```hcl
resource "aws_security_group" "ec2" {
  ingress {
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]  # ALB sg only
  }
  egress { ... all traffic ... }
}
```

Allows port 8000 traffic **only from the ALB security group** — not directly from the internet. This enforces that all traffic must pass through the ALB. Egress is unrestricted (required for EC2 to reach API Gateway and install packages).

---

## Application Load Balancer

### ALB Resource

```hcl
resource "aws_lb" "hello_world" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = data.aws_subnets.default.ids
}
```

- **`internal = false`** — internet-facing (has a public DNS name)
- **`load_balancer_type = "application"`** — Layer 7 (HTTP/HTTPS aware), as opposed to network (TCP) or gateway
- **`subnets`** — all default subnets for multi-AZ placement; ALBs require at least 2 subnets in different AZs

### Target Group

```hcl
resource "aws_lb_target_group" "fastapi" {
  port     = 8000
  protocol = "HTTP"

  health_check {
    path                = "/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }
}
```

Defines where the ALB sends traffic:
- **`port = 8000`** — FastAPI listens here on EC2
- **`/health`** — ALB polls this endpoint every 30s; the instance is marked healthy after 2 consecutive `200` responses, and unhealthy after 3 failures

### HTTP Listener

```hcl
resource "aws_lb_listener" "http" {
  port     = 80
  protocol = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.fastapi.arn
  }
}
```

Listens on port 80 and forwards all traffic to the FastAPI target group.

---

## IAM Instance Profile

```hcl
resource "aws_iam_role" "ec2_instance" { ... }
resource "aws_iam_role_policy_attachment" "ssm" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
resource "aws_iam_instance_profile" "ec2" { ... }
```

Grants the EC2 instance the `AmazonSSMManagedInstanceCore` policy, enabling **AWS Systems Manager Session Manager** access. This means you can connect to the instance via the AWS console or CLI without opening SSH port 22 or managing SSH keys.

---

## EC2 Instance

```hcl
resource "aws_instance" "hello_world" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.ec2_instance_type   # t2.micro
  iam_instance_profile   = aws_iam_instance_profile.ec2.name
  vpc_security_group_ids = [aws_security_group.ec2.id]
  subnet_id              = tolist(data.aws_subnets.default.ids)[0]

  user_data = base64encode(templatefile("${path.module}/userdata.sh.tpl", {
    api_gateway_url = aws_apigatewayv2_stage.default.invoke_url
  }))
}
```

Key attributes:
- **`instance_type`** — `t2.micro` (1 vCPU, 1 GiB RAM) — within the free-tier and the account's 1-vCPU limit
- **`user_data`** — a base64-encoded shell script generated from `userdata.sh.tpl`; runs once on first boot to install and start FastAPI
- **`templatefile(...)`** — injects the `api_gateway_url` so the FastAPI service knows where to call the Lambda
- **`subnet_id`** — `tolist(...)[0]` picks the first available default subnet

### Target Group Attachment

```hcl
resource "aws_lb_target_group_attachment" "hello_world" {
  target_group_arn = aws_lb_target_group.fastapi.arn
  target_id        = aws_instance.hello_world.id
  port             = 8000
}
```

Registers the EC2 instance as a target in the ALB target group on port 8000. Once the instance passes the health check at `/health`, the ALB starts routing requests to it.
