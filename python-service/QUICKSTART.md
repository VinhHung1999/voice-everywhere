# Quick Start Guide - Speaker Verification Service

**Time to setup:** ~10 minutes
**Requirements:** macOS with Python 3.9+

---

## Setup (One-Time)

### Option 1: Automated Setup (Recommended)

```bash
cd python-service
./setup.sh
```

This will:
- ✅ Create virtual environment
- ✅ Install all dependencies (~2GB, takes 5-10 minutes)
- ✅ Verify installation

### Option 2: Manual Setup

```bash
cd python-service

# Create venv
python3 -m venv venv

# Activate venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

---

## Start Service

### Option 1: Using start script

```bash
./start.sh
```

### Option 2: Manual start

```bash
source venv/bin/activate
uvicorn verify_service:app --port 8765
```

**Expected output:**
```
🚀 Starting Speaker Verification Service...
📦 Loading SpeechBrain ECAPA-TDNN model...
✅ Model loaded successfully
🌐 Service ready on http://localhost:8765
```

---

## Test Service

Open a new terminal:

```bash
# Health check
curl http://localhost:8765/health

# Expected: {"status":"healthy","model_loaded":true,...}
```

---

## Troubleshooting

### Error: "externally-managed-environment" (PEP 668)

**Problem:** macOS Sonoma+ blocks system Python modifications

**Solution:** Use virtual environment (setup.sh does this automatically)

```bash
# If you see this error, use:
./setup.sh
```

### Error: "torch not available for 2.5.1"

**Problem:** torch 2.5.1 not available on PyPI

**Solution:** Updated to torch>=2.6.0 (already fixed in requirements.txt)

### Error: "command not found: uvicorn"

**Problem:** Virtual environment not activated

**Solution:**
```bash
source venv/bin/activate
```

### Slow installation

**Normal:** torch/torchaudio are ~2GB downloads
**Time:** 5-10 minutes on fast internet

---

## Complete Workflow

```bash
# 1. Setup (one-time, ~10 minutes)
cd python-service
./setup.sh

# 2. Start service
./start.sh

# 3. In another terminal: Test
curl http://localhost:8765/health

# 4. Ready for VoiceEverywhere app!
```

---

## Integration with VoiceEverywhere App

1. **Setup Python service** (this guide)
2. **Start service** (`./start.sh`)
3. **Open VoiceEverywhere app**
4. **Record enrollment samples** (Settings → Voice Enrollment)
5. **Enable verification** (Settings → "Enable speaker verification")
6. **Test** (Press ⌃⌥Space and speak)

---

## Service Management

**Start:**
```bash
./start.sh
```

**Stop:**
```
Press Ctrl+C
```

**Restart:**
```bash
# Stop (Ctrl+C), then:
./start.sh
```

**Check status:**
```bash
curl http://localhost:8765/health
```

---

## Files Created

| Path | Purpose |
|------|---------|
| `venv/` | Virtual environment (created by setup.sh) |
| `pretrained_models/` | Downloaded ECAPA-TDNN model (~80MB) |
| `~/Library/Application Support/VoiceEverywhere/voice_profile/` | Enrollment samples + profile |

---

## Need Help?

See: `README.md` for full documentation
