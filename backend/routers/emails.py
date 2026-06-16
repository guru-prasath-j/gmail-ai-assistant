from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional
import httpx, base64, email as email_lib, re, html as html_lib
from html.parser import HTMLParser
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

class _HTMLStripper(HTMLParser):
    """Extracts visible text from HTML.

    Skips:
    - <script>, <style>, <head>, <noscript> tags (and their content)
    - Any element with style containing display:none or max-height:0
    """

    # Tags that generate no closing tag in HTML5
    _VOID = {"area","base","br","col","embed","hr","img",
             "input","link","meta","param","source","track","wbr"}
    # Tags that introduce a line break in plain text
    _BLOCK = {"p","div","tr","li","h1","h2","h3","h4","h5","h6",
              "table","ul","ol","blockquote","section","article","header","footer"}
    _ALWAYS_SKIP = {"script","style","head","noscript"}

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self._parts: list[str] = []
        self._skip_depth = 0   # >0 means we are inside an invisible/skip zone

    @staticmethod
    def _is_invisible(attrs_list) -> bool:
        for name, value in (attrs_list or []):
            if name == "style" and value:
                if re.search(r"display\s*:\s*none", value, re.IGNORECASE):
                    return True
                if re.search(r"max-height\s*:\s*0+\s*(px)?[^0-9]", value, re.IGNORECASE):
                    return True
                if re.search(r"visibility\s*:\s*hidden", value, re.IGNORECASE):
                    return True
        return False

    def handle_starttag(self, tag, attrs):
        tag_l = tag.lower()
        is_void = tag_l in self._VOID

        # Already inside a skip zone — count depth but don't emit
        if self._skip_depth > 0:
            if not is_void:
                self._skip_depth += 1
            return

        # Should this element be skipped?
        if tag_l in self._ALWAYS_SKIP or self._is_invisible(attrs):
            if not is_void:
                self._skip_depth += 1
            return

        # Visible element — emit a newline for block-level tags
        if tag_l in self._BLOCK:
            self._parts.append("\n")
        elif tag_l == "br":
            self._parts.append("\n")

    def handle_endtag(self, tag):
        if self._skip_depth > 0:
            self._skip_depth -= 1

    def handle_data(self, data):
        if self._skip_depth == 0:
            self._parts.append(data)

    def get_text(self) -> str:
        text = "".join(self._parts)
        # Collapse runs of spaces/tabs; normalise excess newlines
        text = re.sub(r"[ \t]+", " ", text)
        text = re.sub(r" *\n *", "\n", text)
        text = re.sub(r"\n{3,}", "\n\n", text)
        return text.strip()


def strip_html(html: str) -> str:
    stripper = _HTMLStripper()
    try:
        stripper.feed(html)
    except Exception:
        # Malformed HTML fallback
        plain = re.sub(r"<[^>]+>", " ", html)
        return html_lib.unescape(plain).strip()
    text = stripper.get_text()
    # If stripping produced almost nothing, the email was image-only or tracking-only
    return text if len(text) > 10 else ""


def extract_body_html(payload: dict) -> str:
    """Return the raw HTML body for display (prefer text/html part)."""
    if not payload:
        return ""
    mime = payload.get("mimeType", "")
    parts = payload.get("parts", [])
    if parts:
        for part in parts:
            if part.get("mimeType") == "text/html" and part.get("body", {}).get("data"):
                return decode_b64(part["body"]["data"])
        for part in parts:
            result = extract_body_html(part)
            if result:
                return result
    if mime == "text/html":
        data = payload.get("body", {}).get("data")
        if data:
            return decode_b64(data)
    return ""


def extract_body(payload: dict) -> str:
    """Extract plain-text body from a Gmail message payload.

    Priority order:
      1. text/plain part (any depth)
      2. text/html part stripped to plain text
    """
    if not payload:
        return ""

    mime = payload.get("mimeType", "")

    # Direct text/plain — best case
    if mime == "text/plain":
        data = payload.get("body", {}).get("data")
        if data:
            return decode_b64(data)

    # Recurse into multipart children, preferring plain text
    parts = payload.get("parts", [])
    if parts:
        # First pass: plain text
        for part in parts:
            if part.get("mimeType") == "text/plain" and part.get("body", {}).get("data"):
                return decode_b64(part["body"]["data"])
        # Second pass: recurse (handles nested multipart/alternative etc.)
        for part in parts:
            result = extract_body(part)
            if result:
                return result

    # Fallback: top-level body data — strip HTML if needed
    data = payload.get("body", {}).get("data")
    if data:
        raw = decode_b64(data)
        if mime == "text/html" or raw.lstrip().startswith("<"):
            return strip_html(raw)
        return raw

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
            "body": extract_body(detail.get("payload", {}))[:3000] or detail.get("snippet", ""),
            "body_html": extract_body_html(detail.get("payload", {})),
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
