# `app/requirements.txt` — Python Dependencies

**Location:** `app/requirements.txt`  
**Used by:** Local development; the EC2 user data script installs these packages directly via `pip3 install`

---

## Contents

```
fastapi==0.115.6
uvicorn[standard]==0.34.0
httpx==0.28.1
```

All versions are **pinned** to ensure reproducible installs — the same library versions are used locally, on EC2, and in any future CI environment.

---

## Package Breakdown

### `fastapi==0.115.6`

FastAPI is a modern, high-performance Python web framework built on top of **Starlette** (ASGI toolkit) and **Pydantic** (data validation).

Key features used in this project:
- Decorator-based route definition (`@app.get(...)`)
- `HTMLResponse` class for returning raw HTML
- Automatic OpenAPI docs at `/docs` (available automatically at `http://<alb-url>/docs`)

### `uvicorn[standard]==0.34.0`

Uvicorn is an **ASGI server** — it's the process that listens on port 8000 and handles HTTP connections, feeding requests into the FastAPI app.

The `[standard]` extra installs optional performance dependencies:
- **`uvloop`** — a faster replacement for Python's default event loop (UNIX only)
- **`httptools`** — a faster HTTP parser
- **`websockets`** — WebSocket support (not used in this project, but included for completeness)

### `httpx==0.28.1`

`httpx` is an async-capable HTTP client for Python. It is used in `main.py` to make outbound requests to the API Gateway endpoint.

It is preferred over `requests` in this project because:
- FastAPI routes use `async def`, so outbound I/O must also be async to avoid blocking the event loop
- `httpx.AsyncClient` integrates natively with Python's `asyncio`

---

## Installation

```bash
# Local development
pip install -r app/requirements.txt

# On EC2 (done automatically by userdata.sh.tpl)
pip3 install fastapi==0.115.6 "uvicorn[standard]==0.34.0" httpx==0.28.1
```
