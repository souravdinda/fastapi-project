# `terraform/userdata.sh.tpl` — EC2 Bootstrap Script

**Location:** `terraform/userdata.sh.tpl`  
**Type:** Terraform template file (`.tpl`)  
**Role:** Bootstraps the EC2 instance on first boot — installs Python/FastAPI, writes the app, and starts it as a systemd service

---

## Purpose

AWS EC2 **user data** is a shell script that runs **once** automatically when the instance first starts. Terraform renders this template (substituting variables) and passes the result to the EC2 instance via the `user_data` attribute.

---

## Template Variable

```hcl
templatefile("${path.module}/userdata.sh.tpl", {
  api_gateway_url = aws_apigatewayv2_stage.default.invoke_url
})
```

The template receives one variable from Terraform:

| Variable | Value | Purpose |
|----------|-------|---------|
| `api_gateway_url` | `https://t06rzdadnk.execute-api.us-east-1.amazonaws.com/` | Injected into the systemd unit as `API_GATEWAY_URL` env var so FastAPI knows the Lambda endpoint |

In the template file, `${api_gateway_url}` is replaced by its value at apply time.

---

## Script Breakdown

### Shebang and Safety Flags

```bash
#!/bin/bash
set -euxo pipefail
```

- **`-e`** — exit immediately if any command fails
- **`-u`** — treat undefined variables as errors
- **`-x`** — print each command before executing it (visible in `/var/log/cloud-init-output.log`)
- **`-o pipefail`** — a pipeline fails if any stage fails (not just the last)

These flags ensure the script fails fast and loudly rather than silently half-completing.

---

### System Update and Python Installation

```bash
dnf update -y
dnf install -y python3 python3-pip
```

Uses **DNF** (Amazon Linux 2023's package manager, replacing YUM). Installs Python 3 and pip from the Amazon repos. The `-y` flag auto-confirms prompts.

---

### Install Python Dependencies

```bash
pip3 install fastapi==0.115.6 "uvicorn[standard]==0.34.0" httpx==0.28.1
```

Installs the three pinned packages directly to the system Python. Versions match `app/requirements.txt` exactly to guarantee consistency.

---

### Write the FastAPI App

```bash
mkdir -p /opt/app
cat > /opt/app/main.py << 'PYEOF'
...
PYEOF
```

Uses a **heredoc** (`<< 'PYEOF'`) to write the full FastAPI application source code to `/opt/app/main.py`. The **single-quoted delimiter** (`'PYEOF'`) prevents the shell from expanding `$` variables inside the heredoc — important because the FastAPI f-strings use `{...}` syntax that would otherwise be misinterpreted.

The app embedded here is functionally identical to `app/main.py` in the repository.

---

### Create the systemd Service Unit

```bash
cat > /etc/systemd/system/fastapi.service << SVCEOF
[Unit]
Description=FastAPI Hello World
After=network.target

[Service]
User=root
WorkingDirectory=/opt/app
Environment="API_GATEWAY_URL=${api_gateway_url}"
ExecStart=/usr/local/bin/uvicorn main:app --host 0.0.0.0 --port 8000
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SVCEOF
```

Creates a **systemd unit file** that manages the FastAPI process:

| Directive | Purpose |
|-----------|---------|
| `After=network.target` | Waits for network to be up before starting |
| `User=root` | Run as root (simplest for a demo; use a dedicated user in production) |
| `WorkingDirectory=/opt/app` | uvicorn imports `main:app` relative to this directory |
| `Environment="API_GATEWAY_URL=..."` | Passes the Terraform-injected API Gateway URL to the process |
| `ExecStart=...uvicorn main:app --host 0.0.0.0 --port 8000` | Binds FastAPI to all interfaces on port 8000 |
| `Restart=always` | Auto-restarts the process if it crashes |
| `RestartSec=5` | Waits 5 seconds before restarting to avoid tight crash loops |

Note: the **unquoted delimiter** (`SVCEOF`) allows `${api_gateway_url}` to be substituted by the shell (since this is the Terraform-rendered value being injected).

---

### Enable and Start

```bash
systemctl daemon-reload   # reload systemd to pick up the new unit file
systemctl enable fastapi  # auto-start on reboot
systemctl start fastapi   # start immediately
```

After these commands, FastAPI is running on port 8000 and will survive instance reboots.

---

## Debugging Tips

SSH is not available (no key pair, port 22 not open). To inspect the bootstrap log:

```bash
# Via SSM Session Manager
aws ssm start-session --target <instance-id> --profile joel

# On the instance:
cat /var/log/cloud-init-output.log   # full bootstrap log
systemctl status fastapi             # service status
journalctl -u fastapi -f             # live FastAPI logs
```
