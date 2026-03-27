# `terraform/main.tf` — Lambda and API Gateway Infrastructure

**Location:** `terraform/main.tf`  
**Role:** Defines the serverless backend — Lambda function + API Gateway HTTP API

---

## Purpose

This file is the primary Terraform configuration. It sets up:
- Terraform version and provider requirements
- AWS provider authentication (region + named profile)
- Lambda function packaging, IAM role, and function resource
- API Gateway v2 (HTTP API) with routing and Lambda integration

---

## Terraform Block

```hcl
terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }

  backend "s3" {
    bucket = "demo1bucket90"
    key    = "joel-hello/terraform.tfstate"
    region = "us-east-1"
  }
}
```

- **`required_version`** — enforces Terraform CLI ≥ 1.3.0 to use features like `optional()` type constraints
- **`hashicorp/aws ~> 5.0`** — allows any `5.x` patch version; prevents accidental major-version upgrades
- **`hashicorp/archive`** — used to ZIP local files (the Lambda source) without external tooling
- **`backend "s3"`** — stores the state securely in the `demo1bucket90` S3 bucket. Allows multiple developers/CI to work on the same infrastructure without state conflicts.

---

## AWS Provider

```hcl
provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}
```

- **`region`** — controlled by `var.aws_region` (default `us-east-1`)
- **`profile`** — controlled by `var.aws_profile` (default `joel`); tells the AWS SDK to use the named profile from `~/.aws/credentials` or `~/.aws/config`. In CI, this is overridden to an empty string so environment-variable credentials are used instead.

---

## Lambda Packaging

```hcl
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../src"
  output_path = "${path.module}/../build/lambda.zip"
}
```

`archive_file` is a **data source** (read-only). It zips the entire `src/` directory at plan/apply time and writes `build/lambda.zip`. The `build/` directory is gitignored.

---

## IAM Resources

### Execution Role

```hcl
resource "aws_iam_role" "lambda_exec" {
  name = "${var.project_name}-lambda-exec"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}
```

Creates an IAM role that **only** the Lambda service can assume (`sts:AssumeRole`). This is the role the function runs as.

### Policy Attachment

```hcl
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
```

Attaches the AWS-managed `AWSLambdaBasicExecutionRole` policy, which grants permission to write logs to **CloudWatch Logs** — the minimum required for any Lambda function.

---

## Lambda Function

```hcl
resource "aws_lambda_function" "hello_world" {
  function_name    = "${var.project_name}-hello-world"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  tags             = var.tags
}
```

Key attributes:
- **`handler`** — `"handler.lambda_handler"` → file `handler.py`, function `lambda_handler`
- **`runtime`** — `python3.12` (latest stable Python Lambda runtime)
- **`source_code_hash`** — a base64-SHA256 of the ZIP content; Terraform uses this to detect code changes and re-deploy even if the filename is unchanged

---

## API Gateway v2 (HTTP API)

### API

```hcl
resource "aws_apigatewayv2_api" "hello_world" {
  name          = "${var.project_name}-api"
  protocol_type = "HTTP"
}
```

Creates an **HTTP API** (v2), which is cheaper and lower-latency than the older REST API (v1). The `HTTP` protocol type enables the simplified payload format v2.0.

### Stage

```hcl
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.hello_world.id
  name        = "$default"
  auto_deploy = true
}
```

The `$default` stage is a special catch-all stage for HTTP APIs. `auto_deploy = true` means changes to routes/integrations are deployed immediately without a manual deploy step.

### Integration

```hcl
resource "aws_apigatewayv2_integration" "lambda" {
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.hello_world.invoke_arn
  payload_format_version = "2.0"
}
```

`AWS_PROXY` means API Gateway passes the full HTTP request to Lambda as a JSON event and passes Lambda's response back directly. `payload_format_version = "2.0"` uses the newer, simpler event schema.

### Route

```hcl
resource "aws_apigatewayv2_route" "get_hello" {
  route_key = "GET /"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}
```

Maps `GET /` to the Lambda integration. Only this route is defined; any other path returns a 404.

### Lambda Permission

```hcl
resource "aws_lambda_permission" "apigw" {
  action        = "lambda:InvokeFunction"
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.hello_world.execution_arn}/*/*"
}
```

Grants API Gateway permission to invoke the Lambda function. The `source_arn` with `/*/*` allows any stage and any route on this API to trigger the function.
