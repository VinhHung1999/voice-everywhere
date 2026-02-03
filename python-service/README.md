# Speaker Verification Service

Production FastAPI service using SpeechBrain ECAPA-TDNN for speaker verification.

**Story:** STORY-003 [P0]
**Model:** speechbrain/spkrec-ecapa-voxceleb
**Target Latency:** <500ms per verification

---

## Features

- ✅ Real-time speaker verification using ECAPA-TDNN
- ✅ Enrollment from WAV files (automatic averaging of samples)
- ✅ Configurable verification threshold (default: 0.25)
- ✅ Verification logging for threshold tuning
- ✅ Auto-resampling to 16kHz if needed
- ✅ Health check and status endpoints

---

## Installation

### Quick Start (Automated)

```bash
cd python-service
./setup.sh
```

This creates a virtual environment and installs all dependencies (~2GB, 5-10 minutes).

**See:** `QUICKSTART.md` for step-by-step guide

### Manual Installation

```bash
cd python-service

# Create virtual environment (required on macOS Sonoma+)
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

**Dependencies:**
- fastapi==0.115.6
- uvicorn[standard]==0.34.0
- python-multipart==0.0.20
- speechbrain==1.0.3
- torch==2.8.0 (pinned - last version compatible with speechbrain)
- torchaudio==2.8.0 (pinned - last version with list_audio_backends())
- numpy==1.26.4

**Important Notes:**
- Virtual environment is **required** on macOS Sonoma+ (PEP 668)
- First run downloads ECAPA-TDNN model (~80MB) to `pretrained_models/`
- Total installation size: ~2GB

---

## Usage

### Start Service

**Option 1: Using start script (Recommended)**

```bash
./start.sh
```

**Option 2: Manual start**

```bash
source venv/bin/activate
uvicorn verify_service:app --port 8765 --log-level info
```

Expected startup output:
```
🚀 Starting Speaker Verification Service...
📦 Loading SpeechBrain ECAPA-TDNN model...
✅ Model loaded successfully
⚠️  No enrolled speaker profile found
🌐 Service ready on http://localhost:8765
📊 Verification threshold: 0.25
```

Service will be available at: `http://localhost:8765`

**Stop service:** Press `Ctrl+C`

---

## API Endpoints

### GET / - Service Info

```bash
curl http://localhost:8765/
```

Response:
```json
{
  "service": "Speaker Verification API",
  "status": "running",
  "version": "1.0.0",
  "model": "speechbrain/spkrec-ecapa-voxceleb",
  "model_loaded": true,
  "enrolled": false
}
```

### GET /health - Health Check

```bash
curl http://localhost:8765/health
```

Response:
```json
{
  "status": "healthy",
  "model_loaded": true,
  "enrolled_speaker": false,
  "threshold": 0.25
}
```

### GET /status - Enrollment Status

```bash
curl http://localhost:8765/status
```

Response:
```json
{
  "model_loaded": true,
  "enrollment_status": "enrolled",
  "sample_count": 5,
  "threshold": 0.25,
  "enrolled_profile_exists": true
}
```

### POST /enroll - Enroll Speaker

Reads WAV files from `~/Library/Application Support/VoiceEverywhere/voice_profile/` (created by STORY-002).

```bash
curl -X POST http://localhost:8765/enroll
```

**Prerequisites:**
- Record 3-5 voice samples using VoiceEverywhere app (STORY-002)
- Samples should be 3-5 seconds each

Response:
```json
{
  "status": "enrolled",
  "samples_processed": 5,
  "samples_found": 5,
  "processing_time_s": 3.45,
  "profile_saved": "/Users/username/Library/Application Support/VoiceEverywhere/voice_profile/enrolled_profile.pt"
}
```

### POST /verify - Verify Speaker

Verify if audio contains the enrolled speaker's voice.

```bash
curl -X POST http://localhost:8765/verify \
     -F "audio=@test_audio.wav"
```

Response (VERIFIED):
```json
{
  "verified": true,
  "score": 0.7234,
  "threshold": 0.25,
  "audio_size_kb": 93.75,
  "processing_time_ms": 287.45
}
```

Response (REJECTED):
```json
{
  "verified": false,
  "score": 0.1523,
  "threshold": 0.25,
  "audio_size_kb": 93.75,
  "processing_time_ms": 289.12
}
```

### POST /set_threshold - Update Threshold

```bash
curl -X POST "http://localhost:8765/set_threshold?threshold=0.30"
```

Response:
```json
{
  "status": "updated",
  "old_threshold": 0.25,
  "new_threshold": 0.30
}
```

---

## Workflow

### Complete Enrollment & Verification Flow

1. **Record Samples (STORY-002)**
   - Open VoiceEverywhere app
   - Go to Settings → Voice Enrollment
   - Record 5 voice samples (3-5 seconds each)

2. **Start Service**
   ```bash
   uvicorn verify_service:app --port 8765
   ```

3. **Enroll Speaker**
   ```bash
   curl -X POST http://localhost:8765/enroll
   ```

4. **Verify Audio**
   ```bash
   # Test with your own voice (should verify)
   curl -X POST http://localhost:8765/verify \
        -F "audio=@my_voice.wav"

   # Test with someone else's voice (should reject)
   curl -X POST http://localhost:8765/verify \
        -F "audio=@other_voice.wav"
   ```

---

## File Paths

| Purpose | Path |
|---------|------|
| Enrollment samples | `~/Library/Application Support/VoiceEverywhere/voice_profile/sample_*.wav` |
| Enrolled profile | `~/Library/Application Support/VoiceEverywhere/voice_profile/enrolled_profile.pt` |
| Verification log | `~/Library/Logs/VoiceEverywhere/verification.log` |
| Model cache | `python-service/pretrained_models/` |

---

## Verification Logging

All verification attempts are logged to `~/Library/Logs/VoiceEverywhere/verification.log` in JSON Lines format:

```json
{"timestamp": "2026-02-03T11:20:15.123456", "verified": true, "score": 0.7234, "threshold": 0.25, "audio_size_kb": 93.75, "processing_time_ms": 287.45}
{"timestamp": "2026-02-03T11:21:03.789012", "verified": false, "score": 0.1523, "threshold": 0.25, "audio_size_kb": 88.12, "processing_time_ms": 289.12}
```

**Use for:**
- Threshold tuning (analyze score distribution)
- Performance monitoring
- False positive/negative analysis

---

## Threshold Tuning Guide

### Default Threshold: 0.25

Based on [SpeechBrain ECAPA-TDNN research](https://huggingface.co/speechbrain/spkrec-ecapa-voxceleb):
- **EER (Equal Error Rate):** 0.69%
- **Threshold 0.25:** Balanced false positive/negative rate

### Tuning Process

1. **Collect verification logs** (20-50 samples minimum)
   ```bash
   cat ~/Library/Logs/VoiceEverywhere/verification.log
   ```

2. **Analyze score distribution**
   - Owner voice: typically 0.6-0.9
   - Other speakers: typically 0.1-0.3
   - Overlap zone: 0.3-0.5

3. **Adjust threshold**
   - **Higher (0.3-0.4):** Fewer false positives, more false negatives
   - **Lower (0.15-0.2):** Fewer false negatives, more false positives
   - **Default (0.25):** Balanced

4. **Update threshold via API**
   ```bash
   curl -X POST "http://localhost:8765/set_threshold?threshold=0.30"
   ```

---

## Performance Targets

| Metric | Target | Typical |
|--------|--------|---------|
| Model load time | <10s | ~5s |
| Enrollment (5 samples) | <10s | ~3-5s |
| Verification latency | <500ms | ~280-350ms |
| CPU usage (idle) | <5% | ~2% |
| Memory (with model) | <1GB | ~500MB |

---

## Troubleshooting

### Model Download Fails

```bash
# Manually download model
mkdir -p pretrained_models
cd pretrained_models
# Download from HuggingFace: https://huggingface.co/speechbrain/spkrec-ecapa-voxceleb
```

### No Enrollment Samples Found

```bash
# Check if samples exist
ls -la ~/Library/Application\ Support/VoiceEverywhere/voice_profile/

# If missing, record samples using VoiceEverywhere app (Settings → Voice Enrollment)
```

### Verification Always Returns False

1. Check enrollment: `curl http://localhost:8765/status`
2. Check threshold: `curl http://localhost:8765/health`
3. Review logs: `cat ~/Library/Logs/VoiceEverywhere/verification.log`
4. Try lowering threshold: `curl -X POST "http://localhost:8765/set_threshold?threshold=0.20"`

### High Latency (>500ms)

- Check CPU usage (`top`)
- Ensure model running on CPU (not GPU, as macOS M-series GPUs may have compatibility issues)
- Consider shorter audio samples (3s vs 5s)

---

## Testing

### Unit Test (Syntax)

```bash
python3 -m py_compile verify_service.py
```

### Integration Test (Manual)

1. Start service
2. Create test audio files
3. Test each endpoint
4. Verify response format
5. Check logs written

See: `docs/testing/STORY-003-manual-test-plan.md` (to be created by Tester)

---

## Development

### Adding New Endpoints

1. Define endpoint in `verify_service.py`
2. Update this README
3. Test with curl
4. Document in test plan

### Model Upgrade

To upgrade to a different SpeechBrain model:

1. Update model source in `startup_event()`:
   ```python
   verifier = SpeakerRecognition.from_hparams(
       source="speechbrain/NEW_MODEL_NAME",
       savedir="pretrained_models"
   )
   ```

2. Test enrollment and verification
3. Adjust threshold if needed

---

## References

- SpeechBrain ECAPA-TDNN: https://huggingface.co/speechbrain/spkrec-ecapa-voxceleb
- FastAPI docs: https://fastapi.tiangolo.com/
- STORY-001 architecture: `../docs/research/swift-python-integration-architecture.md`
- Vietnamese research: See CLAUDE.md for path

---

## API Summary

| Endpoint | Method | Purpose | Auth |
|----------|--------|---------|------|
| `/` | GET | Service info | No |
| `/health` | GET | Health check | No |
| `/status` | GET | Enrollment status | No |
| `/enroll` | POST | Enroll speaker from WAV files | No |
| `/verify` | POST | Verify speaker from audio | No |
| `/set_threshold` | POST | Update threshold | No |

---

**Version:** 1.0.0
**Last Updated:** 2026-02-03
**Story:** STORY-003 [P0]
