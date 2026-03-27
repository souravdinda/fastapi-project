# `terraform/outputs.tf` — Output Values

**Location:** `terraform/outputs.tf`  
**Role:** Exposes key deployment values after `terraform apply` completes

---

## Purpose

Terraform outputs surface important information that is only known after infrastructure is created (e.g., generated DNS names, ARNs). They are printed at the end of every `apply` and can be queried programmatically.

---

## Outputs Reference

### `api_url`

```hcl
output "api_url" {
  description = "Base URL of the Hello World API"
  value       = aws_apigatewayv2_stage.default.invoke_url
}
```

The **HTTPS** URL of the API Gateway `$default` stage. This is where the Lambda function is accessible directly.

**Example value:**
```
https://t06rzdadnk.execute-api.us-east-1.amazonaws.com/
```

**Usage:**
```bash
curl $(terraform output -raw api_url)
# → {"message": "Hello, World!"}
```

---

### `lambda_function_name`

```hcl
output "lambda_function_name" {
  description = "Name of the deployed Lambda function"
  value       = aws_lambda_function.hello_world.function_name
}
```

The deployed Lambda function name. Useful for invoking or inspecting the function via the AWS CLI:

```bash
# Invoke Lambda directly
aws lambda invoke \
  --function-name $(terraform output -raw lambda_function_name) \
  --profile joel \
  /tmp/response.json && cat /tmp/response.json

# View recent logs
aws logs tail /aws/lambda/$(terraform output -raw lambda_function_name) --follow
```

---

### `alb_url`

```hcl
output "alb_url" {
  description = "HTTP URL of the ALB (FastAPI frontend)"
  value       = "http://${aws_lb.hello_world.dns_name}"
}
```

The **HTTP** URL of the Application Load Balancer — the main user-facing endpoint. This is where the FastAPI app is served.

**Example value:**
```
http://joel-hello-alb-737168400.us-east-1.elb.amazonaws.com
```

**Usage:**
```bash
# Open in browser or test with curl
curl $(terraform output -raw alb_url)
curl $(terraform output -raw alb_url)/health
curl $(terraform output -raw alb_url)/api/hello
```

---

## Querying Outputs

```bash
# All outputs
terraform output

# Single output (raw, no quotes — useful in scripts)
terraform output -raw alb_url

# JSON format (useful for piping to jq)
terraform output -json
```
