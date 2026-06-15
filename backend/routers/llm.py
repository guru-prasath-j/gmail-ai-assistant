from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional
import httpx, json, os
from database import get_style_profile, save_email_reply

router = APIRouter()

OLLAMA_BASE = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434")
OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "llama3.2:1b")
OLLAMA_MODEL_LARGE = os.getenv("OLLAMA_MODEL_LARGE", "llama3.2")

# ── Ollama helpers ────────────────────────────────────────────────────────────

async def ollama_chat(system: str, user: str, temperature: float = 0.7, model: str = None) -> str:
    payload = {
        "model": model or OLLAMA_MODEL,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
        "stream": False,
        "options": {"temperature": temperature},
    }
    try:
        async with httpx.AsyncClient(timeout=300.0) as client:
            r = await client.post(f"{OLLAMA_BASE}/api/chat", json=payload)
        if not r.is_success:
            raise HTTPException(500, f"Ollama error {r.status_code}: {r.text}")
        return r.json()["message"]["content"]
    except HTTPException:
        raise
    except httpx.ConnectError:
        raise HTTPException(503, f"Ollama not reachable at {OLLAMA_BASE}. Run: ollama serve")
    except httpx.TimeoutException as e:
        raise HTTPException(503, f"Ollama timed out — model may be loading, try again. ({type(e).__name__})")
    except Exception as e:
        raise HTTPException(503, f"Ollama request failed ({type(e).__name__}): {e!r}")

async def ollama_generate(prompt: str, temperature: float = 0.7) -> str:
    payload = {
        "model": OLLAMA_MODEL,
        "prompt": prompt,
        "stream": False,
        "options": {"temperature": temperature},
    }
    try:
        async with httpx.AsyncClient(timeout=120.0) as client:
            r = await client.post(f"{OLLAMA_BASE}/api/generate", json=payload)
        return r.json()["response"]
    except httpx.ConnectError:
        raise HTTPException(503, "Ollama not running. Start with: ollama serve")

# ── Models ────────────────────────────────────────────────────────────────────

class AnalyzeRequest(BaseModel):
    samples: list  # [{subject, body}]

class GenerateReplyRequest(BaseModel):
    gmail_message_id: str
    thread_id: str
    subject: str
    sender: str
    body: str
    save: bool = True

class RegenerateRequest(BaseModel):
    gmail_message_id: str
    subject: str
    sender: str
    body: str
    instruction: Optional[str] = None  # "make it shorter", "more formal" etc.

# ── Endpoints ─────────────────────────────────────────────────────────────────

@router.get("/models")
async def list_models():
    """List available Ollama models"""
    try:
        async with httpx.AsyncClient() as client:
            r = await client.get(f"{OLLAMA_BASE}/api/tags")
        models = [m["name"] for m in r.json().get("models", [])]
        return {"models": models, "current": OLLAMA_MODEL}
    except httpx.ConnectError:
        raise HTTPException(503, "Ollama not running")

@router.get("/status")
async def ollama_status():
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            r = await client.get(f"{OLLAMA_BASE}/api/tags")
        models = [m["name"] for m in r.json().get("models", [])]
        return {"running": True, "models": models, "current_model": OLLAMA_MODEL}
    except Exception:
        return {"running": False, "models": [], "current_model": OLLAMA_MODEL}

@router.post("/analyze-tone")
async def analyze_tone(req: AnalyzeRequest):
    """Analyze writing style from email samples"""
    if not req.samples:
        raise HTTPException(400, "No samples provided")

    samples_text = "\n\n".join([
        f"--- Email {i+1} (Subject: {s.get('subject','')}) ---\n{s.get('body','')[:250]}"
        for i, s in enumerate(req.samples[:10])
    ])

    system = """You are an expert linguistic analyst. Analyze email writing style.
Return ONLY valid JSON, no explanation, no markdown. Format:
{
  "tone": "formal|informal|friendly|professional",
  "warmth": "cold|neutral|warm|very warm",
  "formality_score": 1-10,
  "typical_greetings": ["Hi", "Hello"],
  "typical_signoffs": ["Best", "Thanks"],
  "sentence_style": "short and direct|elaborate|mixed",
  "vocabulary_level": "simple|moderate|advanced",
  "key_phrases": ["phrase1", "phrase2"],
  "response_style": "brief responder|detailed explainer|question asker",
  "emoji_usage": "none|rare|moderate|frequent",
  "style_summary": "2-3 sentence description of writing style"
}"""

    raw = await ollama_chat(system, f"Analyze these emails:\n\n{samples_text}", temperature=0.3)

    try:
        clean = raw.strip().replace("```json", "").replace("```", "").strip()
        profile = json.loads(clean)
    except json.JSONDecodeError:
        profile = {"style_summary": raw, "raw": True}

    # Save to DB
    from database import save_style_profile
    save_style_profile(profile, len(req.samples))

    return {"profile": profile, "sample_count": len(req.samples)}


@router.post("/generate-reply")
async def generate_reply(req: GenerateReplyRequest):
    """Generate a reply in user's writing style"""
    style = get_style_profile()
    if not style:
        raise HTTPException(400, "No style profile found. Analyze your emails first.")

    profile = style["profile"]
    style_desc = json.dumps(profile, indent=2) if isinstance(profile, dict) else str(profile)

    system = f"""You are an email assistant that writes replies mimicking a specific person's style exactly.

STYLE PROFILE:
{style_desc}

STRICT RULES:
- Use their exact tone, vocabulary level, and sentence style
- Use their typical greetings and sign-offs
- Match their warmth level exactly
- If they use emojis, use them. If not, don't.
- Write ONLY the reply body. No subject line, no meta text.
- Keep it natural — do NOT sound like AI"""

    user_msg = f"""Write a reply to this email:

From: {req.sender}
Subject: {req.subject}

{req.body[:1500]}"""

    reply = await ollama_chat(system, user_msg, temperature=0.7, model=OLLAMA_MODEL_LARGE)

    if req.save:
        save_email_reply(
            req.gmail_message_id,
            req.thread_id,
            req.subject,
            req.sender,
            req.body[:300],
            reply
        )

    return {"reply": reply, "gmail_message_id": req.gmail_message_id}


@router.post("/regenerate-reply")
async def regenerate_reply(req: RegenerateRequest):
    """Regenerate with optional instruction tweak"""
    style = get_style_profile()
    if not style:
        raise HTTPException(400, "No style profile found")

    profile = style["profile"]
    style_desc = json.dumps(profile, indent=2) if isinstance(profile, dict) else str(profile)

    instruction_part = f"\n\nADDITIONAL INSTRUCTION: {req.instruction}" if req.instruction else ""

    system = f"""You are an email assistant mimicking a specific person's writing style.

STYLE PROFILE:
{style_desc}
{instruction_part}

Write ONLY the reply body. Sound natural, not like AI."""

    reply = await ollama_chat(
        system,
        f"Reply to:\nFrom: {req.sender}\nSubject: {req.subject}\n\n{req.body[:1500]}",
        temperature=0.8,
        model=OLLAMA_MODEL_LARGE,
    )

    from database import update_reply_status
    update_reply_status(req.gmail_message_id, "pending", reply)

    return {"reply": reply}
