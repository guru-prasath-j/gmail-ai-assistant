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
    # Redirect to Flutter deep link
    return RedirectResponse(url=f"gmailai://auth/success?email={email}")

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
