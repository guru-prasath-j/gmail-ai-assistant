from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional
import httpx, base64, email as email_lib
from database import get_tokens, save_email_reply, update_reply_status, get_all_replies

router = APIRouter()

GMAIL_BASE = "https://gmail.googleapis.com/gmail/v1/users/me"

# ── Helpers ───────────────────────────────────────────────────────────────────

async def gmail_get(path: str, token: str):
    async with httpx.AsyncClient() as client:
        r = await client.get(f"{GMAIL_BASE}{path}", headers={"Authorization": f"Bearer {token}"})
    if r.status_code == 401:
        raise HTTPException(401, "Token expired — call /auth/refresh")
    if not r.is_success:
        raise HTTPException(r.status_code, r.text)
    return r.json()

async def gmail_post(path: str, token: str, data: dict):
    async with httpx.AsyncClient() as client:
        r = await client.post(
            f"{GMAIL_BASE}{path}",
            headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
            json=data
        )
    if not r.is_success:
        raise HTTPException(r.status_code, r.text)
    return r.json()

def decode_b64(s: str) -> str:
    try:
        return base64.urlsafe_b64decode(s + "==").decode("utf-8", errors="replace")
    except Exception:
        return ""

def extract_body(payload: dict) -> str:
    if not payload:
        return ""
    if payload.get("body", {}).get("data"):
        return decode_b64(payload["body"]["data"])
    for part in payload.get("parts", []):
        if part.get("mimeType") == "text/plain" and part.get("body", {}).get("data"):
            return decode_b64(part["body"]["data"])
    for part in payload.get("parts", []):
        result = extract_body(part)
        if result:
            return result
    return ""

def get_header(headers: list, name: str) -> str:
    for h in headers:
        if h["name"].lower() == name.lower():
            return h["value"]
    return ""

def encode_message(to: str, subject: str, body: str, thread_id: str = None, reply_to_id: str = None) -> dict:
    msg_str = f"To: {to}\r\nSubject: {subject}\r\nContent-Type: text/plain; charset=utf-8\r\n"
    if reply_to_id:
        msg_str += f"In-Reply-To: {reply_to_id}\r\nReferences: {reply_to_id}\r\n"
    msg_str += f"\r\n{body}"
    raw = base64.urlsafe_b64encode(msg_str.encode()).decode()
    result = {"raw": raw}
    if thread_id:
        result["threadId"] = thread_id
    return result

# ── Endpoints ─────────────────────────────────────────────────────────────────

@router.get("/inbox")
async def get_inbox(max_results: int = 20, unread_only: bool = True):
    import asyncio
    tokens = get_tokens()
    if not tokens:
        raise HTTPException(401, "Not authenticated")

    query = "is:unread" if unread_only else ""
    data = await gmail_get(f"/messages?labelIds=INBOX&q={query}&maxResults={max_results}", tokens["access_token"])
    messages = data.get("messages", [])

    async def fetch_detail(msg):
        detail = await gmail_get(f"/messages/{msg['id']}?format=full", tokens["access_token"])
        headers = detail.get("payload", {}).get("headers", [])
        return {
            "id": detail["id"],
            "threadId": detail.get("threadId"),
            "subject": get_header(headers, "subject") or "(no subject)",
            "from": get_header(headers, "from"),
            "to": get_header(headers, "to"),
            "date": get_header(headers, "date"),
            "snippet": detail.get("snippet", ""),
            "body": extract_body(detail.get("payload", {}))[:3000],
            "unread": "UNREAD" in detail.get("labelIds", []),
        }

    emails = await asyncio.gather(*[fetch_detail(msg) for msg in messages])
    return {"emails": list(emails), "count": len(emails)}


@router.get("/replies")
async def get_replies():
    return {"replies": get_all_replies()}


class SendReplyRequest(BaseModel):
    gmail_message_id: str
    thread_id: str
    to: str
    subject: str
    reply_body: str
    auto_send: bool = False

@router.post("/send-reply")
async def send_reply(req: SendReplyRequest):
    tokens = get_tokens()
    if not tokens:
        raise HTTPException(401, "Not authenticated")

    subject = req.subject if req.subject.startswith("Re:") else f"Re: {req.subject}"
    msg_data = encode_message(req.to, subject, req.reply_body, req.thread_id, req.gmail_message_id)

    result = await gmail_post("/messages/send", tokens["access_token"], msg_data)
    update_reply_status(req.gmail_message_id, "sent", req.reply_body)

    return {"message": "Reply sent", "message_id": result.get("id")}


class UpdateStatusRequest(BaseModel):
    gmail_message_id: str
    status: str  # approved | rejected
    edited_reply: Optional[str] = None

@router.post("/update-status")
async def update_status(req: UpdateStatusRequest):
    update_reply_status(req.gmail_message_id, req.status, req.edited_reply)
    return {"message": f"Status updated to {req.status}"}


@router.post("/mark-read/{message_id}")
async def mark_read(message_id: str):
    tokens = get_tokens()
    if not tokens:
        raise HTTPException(401, "Not authenticated")
    await gmail_post(f"/messages/{message_id}/modify", tokens["access_token"],
                     {"removeLabelIds": ["UNREAD"]})
    return {"message": "Marked as read"}
