# Gmail AI Assistant
> Flutter + FastAPI + Ollama (Local LLM) · Learns your tone · Auto-replies in your voice

---

## Architecture

```
Flutter App (Mobile + Desktop)
        ↓ HTTP (localhost:8000)
FastAPI Backend
    ├── /auth     → Gmail OAuth2
    ├── /emails   → Fetch inbox, send replies
    ├── /llm      → Ollama tone analysis + reply generation
    └── /profile  → Style profile storage
        ↓
Ollama (localhost:11434) + SQLite
```

---

## Prerequisites

| Tool | Install |
|------|---------|
| Python 3.11+ | python.org |
| Flutter 3.x | flutter.dev |
| Ollama | ollama.ai |

---

## Step 1 — Google Cloud Setup (One-time, Free)

1. Go to https://console.cloud.google.com/
2. Create a new project → "Gmail AI"
3. APIs & Services → Enable "Gmail API"
4. APIs & Services → Credentials → Create OAuth 2.0 Client ID
   - Application type: **Web application**
   - Authorized redirect URIs: `http://localhost:8000/auth/callback`
5. Download credentials, copy Client ID & Secret

---

## Step 2 — Backend Setup

```bash
cd backend

# Install dependencies
pip install -r requirements.txt

# Configure credentials
cp .env.example .env
# Edit .env with your Google Client ID & Secret

# Start server
python main.py
# → Running on http://localhost:8000
```

**API Docs:** http://localhost:8000/docs

---

## Step 3 — Ollama Setup

```bash
# Install Ollama
curl -fsSL https://ollama.ai/install.sh | sh

# Pull a model (pick one)
ollama pull llama3          # Best balance (4.7GB)
ollama pull mistral         # Faster, good quality (4.1GB)
ollama pull gemma3:4b       # Lighter option (2.5GB)
ollama pull phi3:mini       # Very fast, smaller (2.2GB)

# Start Ollama (usually auto-starts)
ollama serve
```

Change model in `.env`:
```
OLLAMA_MODEL=mistral
```

---

## Step 4 — Flutter App

```bash
cd flutter_app

# Install dependencies
flutter pub get

# Mobile (connected device or emulator)
flutter run

# Desktop
flutter run -d macos    # or windows / linux
flutter run -d chrome   # Web (CORS already configured)
```

---

## Step 5 — First Run Flow

1. **Check System Status** on Home screen — all 4 dots should be green
2. **Connect Gmail** → opens browser OAuth flow → auto-redirects back
3. **Train Style** → paste exported emails as JSON → AI builds your profile
4. **Open Inbox** → tap "Generate Reply" on any email
5. **Review & Send** or auto-send from the Pending Replies screen

---

## Email Sample Format (for training)

Export emails you've written/replied to:

```json
[
  {
    "subject": "Re: Project Update",
    "body": "Hi Sarah,\n\nThanks for the heads up..."
  },
  {
    "subject": "Re: Meeting Tomorrow",
    "body": "Sounds good! I'll be there at 3pm."
  }
]
```

**Tip:** 15-25 samples gives great results. Mix different email types.

---

## Mobile Deep Link Setup

For OAuth callback to redirect back to the app:

**Android** — add to `android/app/src/main/AndroidManifest.xml`:
```xml
<intent-filter android:autoVerify="true">
  <action android:name="android.intent.action.VIEW"/>
  <category android:name="android.intent.category.DEFAULT"/>
  <category android:name="android.intent.category.BROWSABLE"/>
  <data android:scheme="gmailai" android:host="auth"/>
</intent-filter>
```

**iOS** — add to `ios/Runner/Info.plist`:
```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array><string>gmailai</string></array>
  </dict>
</array>
```

**Desktop/Web** — redirect goes to `gmailai://auth/success` — handle via app_links.

---

## Environment Variables

```env
GOOGLE_CLIENT_ID=your_id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=GOCSPX-xxxx
REDIRECT_URI=http://localhost:8000/auth/callback
OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_MODEL=llama3
```

---

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | /auth/login | Get Google OAuth URL |
| GET | /auth/callback | OAuth callback (auto) |
| GET | /auth/status | Check if authenticated |
| GET | /emails/inbox | Fetch unread emails |
| POST | /emails/send-reply | Send a reply |
| POST | /llm/analyze-tone | Analyze writing style |
| POST | /llm/generate-reply | Generate reply in your style |
| POST | /llm/regenerate-reply | Regenerate with instruction |
| GET | /llm/status | Check Ollama status |
| GET | /profile/ | Get style profile |

Full docs: http://localhost:8000/docs

---

## Troubleshooting

**Ollama timeout** — increase timeout in `routers/llm.py` or use a smaller model like `phi3:mini`

**CORS error** — backend already has `allow_origins=["*"]`, should be fine

**OAuth redirect fails on mobile** — ensure deep link is configured in platform manifests

**Token expired** — call `POST /auth/refresh` or re-login
