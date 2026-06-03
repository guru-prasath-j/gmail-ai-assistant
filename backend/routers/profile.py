from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from database import get_style_profile, save_style_profile, save_samples, get_samples
import json

router = APIRouter()

@router.get("/")
async def get_profile():
    profile = get_style_profile()
    if not profile:
        return {"exists": False}
    return {"exists": True, **profile}

@router.delete("/")
async def delete_profile():
    from database import get_conn
    conn = get_conn()
    conn.execute("DELETE FROM style_profile")
    conn.commit()
    conn.close()
    return {"message": "Profile deleted"}

class SamplesRequest(BaseModel):
    samples: list

@router.post("/samples")
async def upload_samples(req: SamplesRequest):
    save_samples(req.samples)
    return {"message": f"Saved {len(req.samples)} samples"}

@router.get("/samples")
async def list_samples():
    return {"samples": get_samples()}
