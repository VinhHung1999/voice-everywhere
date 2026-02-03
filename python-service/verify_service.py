"""
Speaker Verification Service - Production Implementation

FastAPI service using SpeechBrain ECAPA-TDNN for speaker verification.
Integrates with VoiceEverywhere macOS app for real-time speaker recognition.

Usage:
    uvicorn verify_service:app --port 8765 --log-level info

Endpoints:
    GET  /              - Service info
    GET  /health        - Health check
    POST /enroll        - Enroll speaker from WAV files
    POST /verify        - Verify speaker from audio
    GET  /status        - Get enrollment and model status
    POST /set_threshold - Update verification threshold

Model: speechbrain/spkrec-ecapa-voxceleb (ECAPA-TDNN)
"""

from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.responses import JSONResponse
from typing import Optional, List
import uvicorn
import time
import torch
import torchaudio
import numpy as np
from pathlib import Path
import json
from datetime import datetime
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="Speaker Verification Service",
    description="Production speaker verification using SpeechBrain ECAPA-TDNN",
    version="1.0.0"
)

# Global state
verifier = None
enrolled_embedding = None
verification_threshold = 0.25
model_loaded = False

# Paths
ENROLLMENT_DIR = Path.home() / "Library" / "Application Support" / "VoiceEverywhere" / "voice_profile"
LOG_FILE = Path.home() / "Library" / "Logs" / "VoiceEverywhere" / "verification.log"
ENROLLED_PROFILE_PATH = ENROLLMENT_DIR / "enrolled_profile.pt"

# Ensure log directory exists
LOG_FILE.parent.mkdir(parents=True, exist_ok=True)


@app.on_event("startup")
async def startup_event():
    """Load SpeechBrain ECAPA-TDNN model at startup"""
    global verifier, model_loaded, enrolled_embedding

    logger.info("🚀 Starting Speaker Verification Service...")
    logger.info("📦 Loading SpeechBrain ECAPA-TDNN model...")

    try:
        from speechbrain.inference.speaker import SpeakerRecognition

        # Load pretrained model
        verifier = SpeakerRecognition.from_hparams(
            source="speechbrain/spkrec-ecapa-voxceleb",
            savedir="pretrained_models",
            run_opts={"device": "cpu"}  # Use CPU for macOS compatibility
        )

        model_loaded = True
        logger.info("✅ Model loaded successfully")

        # Try to load enrolled profile if exists
        if ENROLLED_PROFILE_PATH.exists():
            enrolled_embedding = torch.load(ENROLLED_PROFILE_PATH)
            logger.info("🎤 Enrolled speaker profile loaded")
        else:
            logger.info("⚠️  No enrolled speaker profile found")

        logger.info(f"🌐 Service ready on http://localhost:8765")
        logger.info(f"📊 Verification threshold: {verification_threshold}")

    except Exception as e:
        logger.error(f"❌ Failed to load model: {e}")
        model_loaded = False
        raise


@app.get("/")
async def root():
    """Root endpoint - service info"""
    return {
        "service": "Speaker Verification API",
        "status": "running",
        "version": "1.0.0",
        "model": "speechbrain/spkrec-ecapa-voxceleb",
        "model_loaded": model_loaded,
        "enrolled": enrolled_embedding is not None
    }


@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy" if model_loaded else "unhealthy",
        "model_loaded": model_loaded,
        "enrolled_speaker": enrolled_embedding is not None,
        "threshold": verification_threshold
    }


@app.get("/status")
async def get_status():
    """Get detailed status including enrollment info"""
    enrollment_status = "not_enrolled"
    sample_count = 0

    if ENROLLMENT_DIR.exists():
        wav_files = list(ENROLLMENT_DIR.glob("sample_*.wav"))
        sample_count = len(wav_files)
        if sample_count > 0:
            enrollment_status = "enrolled"

    return {
        "model_loaded": model_loaded,
        "enrollment_status": enrollment_status,
        "sample_count": sample_count,
        "threshold": verification_threshold,
        "enrolled_profile_exists": enrolled_embedding is not None
    }


@app.post("/enroll")
async def enroll_speaker():
    """
    Enroll speaker from WAV files in voice_profile directory

    Reads all sample_*.wav files from ~/Library/Application Support/VoiceEverywhere/voice_profile/
    Extracts embeddings from each sample
    Averages embeddings to create speaker profile
    Saves profile for future verification
    """
    global enrolled_embedding

    if not model_loaded:
        raise HTTPException(status_code=503, detail="Model not loaded")

    logger.info("📝 Starting enrollment process...")
    start_time = time.time()

    # Check enrollment directory
    if not ENROLLMENT_DIR.exists():
        raise HTTPException(
            status_code=404,
            detail=f"Enrollment directory not found: {ENROLLMENT_DIR}"
        )

    # Find all sample WAV files
    wav_files = sorted(ENROLLMENT_DIR.glob("sample_*.wav"))

    if len(wav_files) == 0:
        raise HTTPException(
            status_code=404,
            detail="No enrollment samples found. Record samples first using the app."
        )

    logger.info(f"Found {len(wav_files)} enrollment samples")

    # Extract embeddings from each sample
    embeddings = []

    for wav_file in wav_files:
        try:
            # Load audio
            waveform, sr = torchaudio.load(str(wav_file))

            # Resample to 16kHz if needed
            if sr != 16000:
                resampler = torchaudio.transforms.Resample(sr, 16000)
                waveform = resampler(waveform)

            # Extract embedding
            embedding = verifier.encode_batch(waveform)
            embeddings.append(embedding)

            logger.info(f"✓ Processed {wav_file.name}")

        except Exception as e:
            logger.error(f"Failed to process {wav_file.name}: {e}")
            continue

    if len(embeddings) == 0:
        raise HTTPException(
            status_code=500,
            detail="Failed to extract embeddings from any samples"
        )

    # Average embeddings
    enrolled_embedding = torch.mean(torch.stack(embeddings), dim=0)

    # Save enrolled profile
    ENROLLMENT_DIR.mkdir(parents=True, exist_ok=True)
    torch.save(enrolled_embedding, ENROLLED_PROFILE_PATH)

    processing_time = time.time() - start_time

    logger.info(f"✅ Enrollment complete: {len(embeddings)} samples processed in {processing_time:.2f}s")

    return {
        "status": "enrolled",
        "samples_processed": len(embeddings),
        "samples_found": len(wav_files),
        "processing_time_s": round(processing_time, 2),
        "profile_saved": str(ENROLLED_PROFILE_PATH)
    }


@app.post("/verify")
async def verify_speaker(audio: UploadFile = File(...)):
    """
    Verify if audio contains the enrolled speaker's voice

    Accepts: WAV file (16kHz mono recommended)
    Returns: verification result with similarity score
    """
    if not model_loaded:
        raise HTTPException(status_code=503, detail="Model not loaded")

    if enrolled_embedding is None:
        raise HTTPException(
            status_code=400,
            detail="No enrolled speaker. Call /enroll first."
        )

    start_time = time.time()

    # Validate audio file
    if not audio.content_type or "audio" not in audio.content_type:
        raise HTTPException(
            status_code=400,
            detail="Invalid content type. Expected audio file."
        )

    try:
        # Read audio data
        audio_bytes = await audio.read()
        audio_size_kb = len(audio_bytes) / 1024

        # Save to temporary file for torchaudio
        import tempfile
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
            tmp.write(audio_bytes)
            tmp_path = tmp.name

        # Load audio
        waveform, sr = torchaudio.load(tmp_path)

        # Clean up temp file
        Path(tmp_path).unlink()

        # Resample to 16kHz if needed
        if sr != 16000:
            resampler = torchaudio.transforms.Resample(sr, 16000)
            waveform = resampler(waveform)

        # Extract embedding
        test_embedding = verifier.encode_batch(waveform)

        # Compute cosine similarity
        similarity = torch.nn.functional.cosine_similarity(
            enrolled_embedding,
            test_embedding
        ).item()

        # Verification decision
        verified = similarity > verification_threshold

        processing_time = (time.time() - start_time) * 1000  # ms

        # Log verification result
        log_verification(
            verified=verified,
            score=similarity,
            threshold=verification_threshold,
            audio_size_kb=audio_size_kb,
            processing_time_ms=processing_time
        )

        logger.info(
            f"{'✅ VERIFIED' if verified else '❌ REJECTED'}: "
            f"score={similarity:.4f}, threshold={verification_threshold}, "
            f"time={processing_time:.1f}ms"
        )

        return {
            "verified": verified,
            "score": round(similarity, 4),
            "threshold": verification_threshold,
            "audio_size_kb": round(audio_size_kb, 2),
            "processing_time_ms": round(processing_time, 2)
        }

    except Exception as e:
        logger.error(f"Verification error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/set_threshold")
async def set_threshold(threshold: float):
    """Update verification threshold (for tuning)"""
    global verification_threshold

    if not 0.0 <= threshold <= 1.0:
        raise HTTPException(
            status_code=400,
            detail="Threshold must be between 0.0 and 1.0"
        )

    old_threshold = verification_threshold
    verification_threshold = threshold

    logger.info(f"Threshold updated: {old_threshold:.2f} → {threshold:.2f}")

    return {
        "status": "updated",
        "old_threshold": old_threshold,
        "new_threshold": threshold
    }


def log_verification(verified: bool, score: float, threshold: float,
                     audio_size_kb: float, processing_time_ms: float):
    """Log verification results to file for analysis and tuning"""
    log_entry = {
        "timestamp": datetime.now().isoformat(),
        "verified": verified,
        "score": round(score, 4),
        "threshold": threshold,
        "audio_size_kb": round(audio_size_kb, 2),
        "processing_time_ms": round(processing_time_ms, 2)
    }

    # Append to log file
    with open(LOG_FILE, "a") as f:
        f.write(json.dumps(log_entry) + "\n")


if __name__ == "__main__":
    uvicorn.run(
        app,
        host="127.0.0.1",
        port=8765,
        log_level="info"
    )
