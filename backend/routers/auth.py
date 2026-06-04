from fastapi import APIRouter, HTTPException
from fastapi.responses import RedirectResponse
from pydantic import BaseModel
import httpx, os, json
from datetime import datetime, timedelta
from database import save_tokens, get_tokens

router = APIRouter()

# ── Load from .env or set directly ──────────────────────────────────────────
CLIENT_ID     = os.getenv("GOOGLE_CLIENT_ID", "YOUR_CLIENT_ID")
CLIENT_SECRET = os.getenv("GOOGLE_CLIENT_SECRET", "YOUR_CLIENT_SECRET")
REDIRECT_URI  = os.getenv("REDIRECT_URI", "http://localhost:8000/auth/callback")
SCOPES        = "https://www.googleapis.com/auth/gmail.modify openid email"

# ── OAuth2 Flow ───────────────────────────────────────────────────────────────

@router.get("/login")
async def login():
    url = (
        "https://accounts.google.com/o/oauth2/v2/auth"
        f"?client_id={CLIENT_ID}"
        f"&redirect_uri={REDIRECT_URI}"
        f"&response_type=code"
        f"&scope={SCOPES.replace(' ', '%20')}"
        "&access_type=offline"
        "&prompt=consent"
    )
    return {"auth_url": url}

@router.get("/callback")
async def callback(code: str):
    async with httpx.AsyncClient() as client:
        resp = await client.post(
            "https://oauth2.googleapis.com/token",
            data={
                "code": code,
                "client_id": CLIENT_ID,
                "client_secret": CLIENT_SECRET,
                "redirect_uri": REDIRECT_URI,
                "grant_type": "authorization_code",
            }
        )
    if resp.status_code != 200:
        raise HTTPException(400, f"Token exchange failed: {resp.text}")

    tokens = resp.json()
    expiry = (datetime.utcnow() + timedelta(seconds=tokens.get("expires_in", 3600))).isoformat()

    # Get user email
    async with httpx.AsyncClient() as client:
        ui = await client.get(
            "https://www.googleapis.com/oauth2/v2/userinfo",
            headers={"Authorization": f"Bearer {tokens['access_token']}"}
        )
    email = ui.json().get("email", "unknown")

    save_tokens(
        tokens["access_token"],
        tokens.get("refresh_token", ""),
        expiry,
        email
    )
    from fastapi.responses import HTMLResponse
    return HTMLResponse(content=f"""
<!DOCTYPE html>
<html>
<head>
  <title>Gmail AI — Connected</title>
  <style>
    body {{ font-family: monospace; background: #08080F; color: #E0E0E0; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; }}
    .box {{ text-align: center; padding: 40px; border: 1px solid #222233; border-radius: 16px; background: #12121F; }}
    .icon {{ font-size: 48px; }}
    h2 {{ color: #00D084; margin: 16px 0 8px; }}
    p {{ color: #888899; font-size: 13px; }}
    .email {{ color: #FF6B35; margin: 8px 0; }}
    button {{ margin-top: 24px; background: #FF6B35; color: white; border: none; padding: 12px 28px; border-radius: 8px; font-family: monospace; font-size: 14px; cursor: pointer; }}
  </style>
</head>
<body>
  <div class="box">
    <div class="icon">✓</div>
    <h2>Gmail Connected!</h2>
    <p class="email">{email}</p>
    <p>Your Gmail account has been connected successfully.<br>Go back to the app and refresh the dashboard.</p>
    <button onclick="window.close()">Close this tab</button>
  </div>
</body>
</html>
""", status_code=200)

@router.post("/refresh")
async def refresh_token():
    tokens = get_tokens()
    if not tokens or not tokens.get("refresh_token"):
        raise HTTPException(401, "No refresh token stored")

    async with httpx.AsyncClient() as client:
        resp = await client.post(
            "https://oauth2.googleapis.com/token",
            data={
                "refresh_token": tokens["refresh_token"],
                "client_id": CLIENT_ID,
                "client_secret": CLIENT_SECRET,
                "grant_type": "refresh_token",
            }
        )
    if resp.status_code != 200:
        raise HTTPException(400, f"Refresh failed: {resp.text}")

    new_tokens = resp.json()
    expiry = (datetime.utcnow() + timedelta(seconds=new_tokens.get("expires_in", 3600))).isoformat()
    save_tokens(new_tokens["access_token"], tokens["refresh_token"], expiry, tokens["email"])
    return {"access_token": new_tokens["access_token"], "email": tokens["email"]}

@router.get("/status")
async def auth_status():
    tokens = get_tokens()
    if not tokens:
        return {"authenticated": False}
    return {"authenticated": True, "email": tokens.get("email")}

@router.delete("/logout")
async def logout():
    from database import get_conn
    conn = get_conn()
    conn.execute("DELETE FROM tokens")
    conn.commit()
    conn.close()
    return {"message": "Logged out"}
