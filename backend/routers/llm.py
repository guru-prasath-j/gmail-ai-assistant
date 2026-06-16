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

    greetings  = profile.get("typical_greetings", ["Hi"])    if isinstance(profile, dict) else ["Hi"]
    signoffs   = profile.get("typical_signoffs",  ["Best"])  if isinstance(profile, dict) else ["Best"]
    tone       = profile.get("tone",       "professional")   if isinstance(profile, dict) else "professional"
    warmth     = profile.get("warmth",     "neutral")        if isinstance(profile, dict) else "neutral"
    sent_style = profile.get("sentence_style", "mixed")      if isinstance(profile, dict) else "mixed"

    system = f"""You are ghostwriting an email reply for a person who RECEIVED an email and needs to respond to it.

Direction: the incoming email arrived IN their inbox. You write their reply BACK to the sender.

THEIR WRITING STYLE:
- Tone: {tone}, warmth: {warmth}, sentences: {sent_style}
- Typical greetings: {", ".join(greetings)}
- Typical sign-offs: {", ".join(signoffs)}
- Full profile: {style_desc}

HOW TO RESPOND — pick the action that fits:
• Event/conference invite  → decide: express intent to register, say you'll look into it, or politely decline
• Question directed at you → answer it clearly
• Request or task          → agree, push back, or ask for details
• Information/update       → acknowledge and react with your next step or opinion
• Newsletter/promo         → brief, natural reaction (interested, not interested, already aware, etc.)

HARD RULES:
1. You are replying TO the sender — the greeting must address the SENDER, not the user.
   The incoming email may say "Hi Narmatha" — that is how the sender greeted the user.
   Your reply greeting must address the sender back (e.g. "Hi," / "Hi Team," / "Hello,").
   NEVER use the user's own name as the greeting in their outgoing reply.
2. You are replying TO the sender, not talking about them or their content.
   WRONG: "Are you planning to attend MongoDB.local?"  ← asking the organiser about their own event
   RIGHT:  "I'd love to join — submitting my registration now."
3. Never open with "Thank you for your email / I received your message."
4. Never repeat or paraphrase what the email said.
5. Use a greeting that addresses the sender, and the person's typical sign-off.
6. Output ONLY the reply body. No subject line, no labels, no meta commentary."""

    user_msg = f"""The user received this email and needs to write a reply back to the sender.

From: {req.sender}
Subject: {req.subject}

--- INCOMING EMAIL ---
{req.body[:1500]}
--- END ---

Write the user's reply to {req.sender}. Address the sender in the greeting, not the user's own name. Be direct and concrete."""

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

    greetings  = profile.get("typical_greetings", ["Hi"])    if isinstance(profile, dict) else ["Hi"]
    signoffs   = profile.get("typical_signoffs",  ["Best"])  if isinstance(profile, dict) else ["Best"]
    tone       = profile.get("tone",       "professional")   if isinstance(profile, dict) else "professional"
    warmth     = profile.get("warmth",     "neutral")        if isinstance(profile, dict) else "neutral"

    instruction_part = f"\n\nSPECIAL INSTRUCTION FOR THIS VERSION: {req.instruction}" if req.instruction else ""

    system = f"""You are ghostwriting an email reply for a person who RECEIVED an email and needs to respond to it.{instruction_part}

Direction: the incoming email arrived IN their inbox. You write their reply BACK to the sender.

THEIR WRITING STYLE:
- Tone: {tone}, warmth: {warmth}
- Typical greetings: {", ".join(greetings)}
- Typical sign-offs: {", ".join(signoffs)}
- Full profile: {style_desc}

HOW TO RESPOND — pick the action that fits:
• Event/conference invite  → decide: express intent to register, say you'll look into it, or politely decline
• Question directed at you → answer it clearly
• Request or task          → agree, push back, or ask for details
• Information/update       → acknowledge and react with your next step or opinion
• Newsletter/promo         → brief, natural reaction (interested, not interested, already aware, etc.)

HARD RULES:
1. The greeting must address the SENDER, not the user.
   The incoming email may say "Hi Narmatha" — that is how the sender greeted the user.
   Your reply must greet the sender back (e.g. "Hi," / "Hi Team," / "Hello,").
   NEVER use the user's own name in the greeting of their outgoing reply.
2. You are replying TO the sender, not talking about them or their content.
   WRONG: "Are you planning to attend the event?"  ← asking the organiser about their own event
   RIGHT:  "Sounds great — I'll register before the deadline."
3. Never open with "Thank you for your email / I received your message."
4. Never repeat or paraphrase what the email said.
5. Use a greeting that addresses the sender, and the user's typical sign-off.
6. Output ONLY the reply body. No subject line, no labels, no meta commentary."""

    reply = await ollama_chat(
        system,
        f"The user received this email and needs to write a reply back to the sender.\n\nFrom: {req.sender}\nSubject: {req.subject}\n\n--- INCOMING EMAIL ---\n{req.body[:1500]}\n--- END ---\n\nWrite the user's reply to {req.sender}. Be direct and concrete.",
        temperature=0.8,
        model=OLLAMA_MODEL_LARGE,
    )

    from database import update_reply_status
    update_reply_status(req.gmail_message_id, "pending", reply)

    return {"reply": reply}
