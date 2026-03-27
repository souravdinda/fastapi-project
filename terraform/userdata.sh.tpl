#!/bin/bash
set -euxo pipefail

# ── System update ────────────────────────────────────────────────────────────
dnf update -y
dnf install -y python3 python3-pip

# ── Install Python deps ───────────────────────────────────────────────────────
pip3 install fastapi==0.115.6 "uvicorn[standard]==0.34.0" httpx==0.28.1

# ── Write the FastAPI app ─────────────────────────────────────────────────────
mkdir -p /opt/app
cat > /opt/app/main.py << 'PYEOF'
import httpx, os
from fastapi import FastAPI
from fastapi.responses import HTMLResponse

API_GATEWAY_URL = os.getenv("API_GATEWAY_URL", "")

app = FastAPI(title="Hello World App", version="1.0.0")

@app.get("/", response_class=HTMLResponse)
async def root():
    api_message = "Hello, World!"
    if API_GATEWAY_URL:
        try:
            async with httpx.AsyncClient(timeout=5) as client:
                resp = await client.get(API_GATEWAY_URL)
                api_message = resp.json().get("message", api_message)
        except Exception:
            pass
    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8"/>
  <meta name="viewport" content="width=device-width,initial-scale=1.0"/>
  <title>Hello World</title>
  <style>
    *{{margin:0;padding:0;box-sizing:border-box}}
    body{{min-height:100vh;display:flex;align-items:center;justify-content:center;
      background:linear-gradient(135deg,#0f0c29,#302b63,#24243e);
      font-family:'Segoe UI',system-ui,sans-serif;color:#fff}}
    .card{{text-align:center;padding:3rem 4rem;
      background:rgba(255,255,255,0.07);border:1px solid rgba(255,255,255,0.15);
      border-radius:1.5rem;backdrop-filter:blur(12px);
      box-shadow:0 20px 60px rgba(0,0,0,0.4);animation:fadeIn 0.8s ease}}
    h1{{font-size:3rem;font-weight:700;letter-spacing:-1px}}
    .badge{{margin-top:1rem;display:inline-block;padding:0.35rem 1rem;
      background:rgba(99,102,241,0.3);border:1px solid rgba(99,102,241,0.6);
      border-radius:999px;font-size:0.85rem;color:#a5b4fc}}
    .stack{{margin-top:2rem;display:flex;gap:0.75rem;justify-content:center;flex-wrap:wrap}}
    .tag{{padding:0.3rem 0.8rem;background:rgba(255,255,255,0.08);
      border-radius:6px;font-size:0.78rem;color:#94a3b8}}
    @keyframes fadeIn{{from{{opacity:0;transform:translateY(20px)}}to{{opacity:1;transform:translateY(0)}}}}
  </style>
</head>
<body>
  <div class="card">
    <h1>{api_message}</h1>
    <div class="badge">✓ EC2 → ALB → FastAPI</div>
    <div class="stack">
      <span class="tag">FastAPI</span><span class="tag">EC2</span>
      <span class="tag">ALB · port 80</span><span class="tag">API Gateway</span>
      <span class="tag">Lambda</span><span class="tag">Terraform</span>
    </div>
  </div>
</body>
</html>"""
    return HTMLResponse(content=html)

@app.get("/api/hello")
async def hello_json():
    if API_GATEWAY_URL:
        try:
            async with httpx.AsyncClient(timeout=5) as client:
                resp = await client.get(API_GATEWAY_URL)
                return resp.json()
        except Exception:
            pass
    return {"message": "Hello, World!"}

@app.get("/health")
def health():
    return {"status": "healthy"}
PYEOF

# ── Systemd service ───────────────────────────────────────────────────────────
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

systemctl daemon-reload
systemctl enable fastapi
systemctl start fastapi
