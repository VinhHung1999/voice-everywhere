"""
Proof of Concept: FastAPI Speaker Verification Service

This is a simplified PoC demonstrating Swift ↔ Python communication
via HTTP REST API. In production, this would include actual SpeechBrain
ECAPA-TDNN model for speaker verification.

Usage:
    uvicorn verify_service:app --port 8765

Test:
    curl -X POST http://localhost:8765/verify \
         -H "Content-Type: audio/wav" \
         --data-binary "@test_audio.wav"
"""

from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.responses import JSONResponse
import uvicorn
import time
import random
from typing import Optional

app = FastAPI(
    title="Speaker Verification Service",
    description="PoC for Swift ↔ Python Integration",
    version="0.1.0"
)

# Simulate "model loaded" state
MODEL_LOADED = True
ENROLLED_SPEAKER = "mock_enrolled_speaker"

@app.on_event("startup")
async def startup_event():
    """Simulate model loading at startup"""
    print("🚀 Starting Speaker Verification Service...")
    print("📦 Loading SpeechBrain ECAPA-TDNN model (simulated)...")
    time.sleep(1)  # Simulate model load time
    print("✅ Model loaded successfully")
    print("🎤 Enrolled speaker profile loaded")
    print("🌐 Service ready on http://localhost:8765")

@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "service": "Speaker Verification API",
        "status": "running",
        "version": "0.1.0 (PoC)"
    }

@app.get("/health")
async def health_check():
    """Health check endpoint for Swift to verify service is ready"""
    return {
        "status": "healthy",
        "model_loaded": MODEL_LOADED,
        "enrolled_speaker": ENROLLED_SPEAKER is not None
    }

@app.post("/verify")
async def verify_speaker(audio: UploadFile = File(...)):
    """
    Verify if audio contains the enrolled speaker's voice

    In production, this would:
    1. Load audio file
    2. Extract F-bank features
    3. Run ECAPA-TDNN inference to get embedding
    4. Compute cosine similarity with enrolled embedding
    5. Return verification result

    For PoC, we simulate this with random verification.
    """
    start_time = time.time()

    # Validate audio file
    if not audio.content_type or "audio" not in audio.content_type:
        raise HTTPException(
            status_code=400,
            detail="Invalid content type. Expected audio file."
        )

    # Read audio data
    audio_bytes = await audio.read()
    audio_size_kb = len(audio_bytes) / 1024

    print(f"📝 Received audio: {audio.filename}, {audio_size_kb:.1f} KB")

    # Simulate speaker verification processing
    # In production: extract features, run ECAPA inference, compute similarity
    await simulate_verification_delay()

    # Mock verification result (80% chance of verification success)
    is_verified = random.random() > 0.2
    similarity_score = random.uniform(0.3, 0.9) if is_verified else random.uniform(0.1, 0.25)

    # Round to 4 decimal places
    similarity_score = round(similarity_score, 4)

    processing_time = round((time.time() - start_time) * 1000, 2)  # ms

    result = {
        "verified": is_verified,
        "score": similarity_score,
        "threshold": 0.25,
        "audio_size_kb": round(audio_size_kb, 2),
        "processing_time_ms": processing_time
    }

    print(f"✅ Verification result: {result}")

    return JSONResponse(content=result)

@app.post("/enroll")
async def enroll_speaker(audio: UploadFile = File(...)):
    """
    Enroll a speaker by processing voice samples

    In production:
    - Accept 3-5 audio samples
    - Extract embeddings from each
    - Average embeddings
    - Save as enrolled speaker profile

    For PoC, we just simulate enrollment.
    """
    audio_bytes = await audio.read()
    audio_size_kb = len(audio_bytes) / 1024

    print(f"📝 Enrolling speaker with audio: {audio.filename}, {audio_size_kb:.1f} KB")

    # Simulate enrollment processing
    await simulate_verification_delay()

    global ENROLLED_SPEAKER
    ENROLLED_SPEAKER = f"speaker_{int(time.time())}"

    return {
        "status": "enrolled",
        "speaker_id": ENROLLED_SPEAKER,
        "audio_size_kb": round(audio_size_kb, 2),
        "message": "Speaker enrolled successfully (PoC simulation)"
    }

async def simulate_verification_delay():
    """Simulate ECAPA-TDNN inference time (~300ms)"""
    import asyncio
    # Real inference: ~300ms
    # Add some randomness to simulate realistic variance
    delay = random.uniform(0.25, 0.35)
    await asyncio.sleep(delay)

if __name__ == "__main__":
    uvicorn.run(
        app,
        host="127.0.0.1",
        port=8765,
        log_level="info"
    )
