# `src/handler.py` — Lambda Function

**Location:** `src/handler.py`  
**Runtime:** Python 3.12  
**Role:** AWS Lambda entry point — the core "hello world" business logic

---

## Purpose

This is the serverless backend. It is packaged into a ZIP file by Terraform and deployed as an AWS Lambda function. API Gateway invokes it on every `GET /` request.

---

## Code Walkthrough

```python
import json
```
Only the standard library `json` module is needed — Lambda functions start with a clean Python environment. No third-party packages are required.

```python
def lambda_handler(event, context):
```
AWS Lambda always calls a function with this exact signature:
- **`event`** — a `dict` containing the HTTP request details forwarded by API Gateway (headers, method, path, body, query params, etc.)
- **`context`** — a Lambda `Context` object with metadata such as `function_name`, `aws_request_id`, memory limits, and remaining execution time

```python
    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps({"message": "Hello, World!"}),
    }
```
This is the **Lambda Proxy Integration response format** required by API Gateway v2 with `payload_format_version = "2.0"`. All three keys are required:
- **`statusCode`** — the HTTP status code that API Gateway forwards to the client
- **`headers`** — HTTP response headers (telling the client this is JSON)
- **`body`** — response body **as a string** (must be serialised with `json.dumps`, not a raw dict)

---

## How It's Packaged

Terraform uses the `archive_file` data source to ZIP the entire `src/` directory:

```hcl
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../src"
  output_path = "${path.module}/../build/lambda.zip"
}
```

The ZIP is then uploaded to Lambda using `filename` + `source_code_hash` (triggers re-deployment when code changes).

---

## Handler Reference

The Terraform resource sets `handler = "handler.lambda_handler"`, which means:
- **`handler`** — filename without `.py` extension (`src/handler.py`)
- **`lambda_handler`** — function name inside that file

---

## Invocation Path

```
API Gateway route "GET /"
  → Integration (AWS_PROXY, payload v2.0)
    → Lambda function: joel-hello-hello-world
      → handler.lambda_handler(event, context)
        → {"statusCode": 200, "body": "{\"message\": \"Hello, World!\"}"}
```

---

## Extension Points

To add more routes, create separate Lambda functions or handle routing inside this function by inspecting `event["routeKey"]` or `event["rawPath"]`.
