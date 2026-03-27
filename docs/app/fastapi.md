# `app/main.py` — FastAPI Web Application

**Location:** `app/main.py`  
**Runtime:** Python (via uvicorn on EC2)  
**Role:** HTTP frontend served through the ALB on port 80

---

## Purpose

This is the HTTP application that end-users interact with. It runs on the EC2 instance as a long-lived process managed by `systemd`. It:
1. Serves a styled HTML "Hello World" page at `GET /`
2. Fetches the greeting message from the Lambda via API Gateway
3. Exposes a JSON proxy endpoint at `GET /api/hello`
4. Exposes a health check at `GET /health` for ALB target group monitoring

---

## Dependencies

```python
import httpx   # async HTTP client — talks to API Gateway
import os      # reads the API_GATEWAY_URL environment variable
from fastapi import FastAPI
from fastapi.responses import HTMLResponse
```

- **`httpx`** — asynchronous HTTP client; chosen over `requests` because FastAPI is async-first
- **`os.getenv`** — reads the `API_GATEWAY_URL` injected by the systemd unit (set in `userdata.sh.tpl`)

---

## Application Instance

```python
API_GATEWAY_URL = os.getenv("API_GATEWAY_URL", "")

app = FastAPI(title="Hello World App", version="1.0.0")
```

`API_GATEWAY_URL` is read once at startup. The empty string default makes the app work locally without AWS credentials — it falls back to a hard-coded `"Hello, World!"`.

---

## Endpoints

### `GET /` — HTML Page

```python
@app.get("/", response_class=HTMLResponse)
async def root():
```

**Flow:**
1. Sets a default message `"Hello, World!"`
2. If `API_GATEWAY_URL` is configured, makes an async HTTP GET to it:
   ```python
   async with httpx.AsyncClient(timeout=5) as client:
       resp = await client.get(API_GATEWAY_URL)
       api_message = resp.json().get("message", api_message)
   ```
   - A **5-second timeout** prevents the page from hanging if Lambda is cold-starting
   - Wrapped in `try/except` — any failure (network error, timeout, bad JSON) silently falls back to the default message; this is a resilience pattern
3. Renders and returns a full HTML page using an f-string template with inline CSS

**Response:** `200 OK` with `Content-Type: text/html`

#### HTML / CSS Design
The page uses a dark glassmorphism card design:
- Background: `linear-gradient(135deg, #0f0c29, #302b63, #24243e)` — deep purple gradient
- Card: semi-transparent (`rgba(255,255,255,0.07)`) with `backdrop-filter: blur(12px)`
- Entry animation: `fadeIn` keyframe (translate + opacity)
- Stack tags display the technology labels used in the project

---

### `GET /api/hello` — JSON Proxy

```python
@app.get("/api/hello")
async def hello_json():
```

Proxies the Lambda response (`{"message": "Hello, World!"}`) directly as JSON. Falls back to returning the same payload locally if `API_GATEWAY_URL` is not set. Useful for testing the Lambda integration independently from the HTML rendering.

---

### `GET /health` — Health Check

```python
@app.get("/health")
def health():
    return {"status": "healthy"}
```

A **synchronous** (non-async) endpoint — no I/O is performed, so there's no benefit to async here. Returns `{"status": "healthy"}` which the ALB target group health check polls every 30 seconds on path `/health`. The ALB marks the EC2 instance as **healthy** only when this returns HTTP 200.

---

## How It Runs on EC2

The app is **not** run directly from `app/main.py`. The `userdata.sh.tpl` script writes a self-contained copy of this app to `/opt/app/main.py` on the EC2 instance at boot time, then starts it via:

```bash
uvicorn main:app --host 0.0.0.0 --port 8000
```

The `app/main.py` file in the repository serves as the canonical source for development and review. The deployed version is identical but embedded in the user data template.

---

## Local Development

```bash
cd app
pip install -r requirements.txt
API_GATEWAY_URL="https://t06rzdadnk.execute-api.us-east-1.amazonaws.com/" \
  uvicorn main:app --reload --port 8000
# → http://localhost:8000
```
