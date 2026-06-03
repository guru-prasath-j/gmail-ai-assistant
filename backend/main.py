from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
import uvicorn
from routers import auth, emails, llm, profile

@asynccontextmanager
async def lifespan(app: FastAPI):
    from database import init_db
    init_db()
    print("✅ Database initialized")
    yield

app = FastAPI(title="Gmail AI Assistant", version="1.0.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router,    prefix="/auth",    tags=["Auth"])
app.include_router(emails.router,  prefix="/emails",  tags=["Emails"])
app.include_router(llm.router,     prefix="/llm",     tags=["LLM"])
app.include_router(profile.router, prefix="/profile", tags=["Profile"])

@app.get("/health")
async def health():
    return {"status": "ok", "message": "Gmail AI Assistant running"}

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
