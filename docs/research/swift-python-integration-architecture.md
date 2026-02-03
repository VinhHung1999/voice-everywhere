# Swift ↔ Python Integration Architecture for Speaker Verification

**Research Date:** 2026-02-03
**Story:** STORY-001 [P0]
**Target:** Integrate SpeechBrain ECAPA-TDNN speaker verification into VoiceEverywhere macOS app
**Requirement:** <2s latency for real-time speaker verification

---

## Executive Summary

This document evaluates three architectural approaches for integrating Python ML models (SpeechBrain ECAPA-TDNN) into our Swift macOS application:

1. **Python Subprocess/Microservice** - External Python process called via HTTP/gRPC
2. **PyTorch Mobile/CoreML** - Convert model to on-device format for native Swift inference
3. **Embedded Python Interpreter** - Bundle Python runtime within the Swift app

**Recommendation:** **HTTP Microservice (FastAPI)** for MVP, with optional migration to CoreML for Phase 2 optimization.

**Key Findings:**
- ✅ HTTP microservice meets <2s latency requirement (~400ms total)
- ✅ Simple to implement, maintain, and debug
- ✅ Model loaded once, amortized cost across requests
- ⚠️ Subprocess approach **fails** latency requirement (2+ seconds with model loading overhead)
- ⚠️ CoreML conversion complex but offers best performance (<100ms)

---

## 1. Approach A: Python Subprocess/Microservice

### Overview

Run Python code as a separate process, communicating via IPC:
- **Subprocess**: One-off `Process.run()` or Swift Subprocess package
- **HTTP REST**: Long-running FastAPI/Flask service
- **gRPC**: High-performance binary protocol

### Implementation Details

#### A1. Subprocess (One-off Python Invocation)

**Swift 6.2+ Subprocess Package:**
```swift
import Subprocess

let result = try await Subprocess.run(
    .named("python3"),
    arguments: ["/path/to/verify_speaker.py", "--audio", audioPath],
    output: .collect(limit: .megabytes(1))
)

let verificationResult = try JSONDecoder().decode(
    VerificationResult.self,
    from: result.standardOutput
)
```

**Pros:**
- Simple implementation
- No service management overhead
- Python environment isolated per invocation

**Cons:**
- **CRITICAL**: Model loading on every call (500-1500ms)
- Process spawn overhead (50-200ms)
- Python import overhead (100-500ms)
- **Total latency: 965-2555ms** - fails <2s requirement

#### A2. HTTP Microservice (FastAPI)

**Architecture:**
```
┌──────────────┐         HTTP POST          ┌──────────────────┐
│ Swift App    │ ────────────────────────▶  │ FastAPI Service  │
│ (URLSession) │ ◀──────────────────────── │ (SpeechBrain)    │
└──────────────┘    JSON Response          └──────────────────┘
                                                   │
                                                   ▼
                                            ECAPA-TDNN Model
                                            (loaded once)
```

**FastAPI Service Example:**
```python
from fastapi import FastAPI, File, UploadFile
from speechbrain.inference.speaker import SpeakerRecognition
import torchaudio
import torch

app = FastAPI()

# Load model once at startup
verifier = SpeakerRecognition.from_hparams(
    source="speechbrain/spkrec-ecapa-voxceleb",
    savedir="pretrained_models"
)

# Load enrolled speaker profile
enrolled_embedding = torch.load("enrolled_speaker.pt")

@app.post("/verify")
async def verify_speaker(audio: UploadFile):
    # Load audio
    waveform, sr = torchaudio.load(audio.file)

    # Extract embedding
    test_embedding = verifier.encode_batch(waveform)

    # Compute similarity
    similarity = torch.nn.functional.cosine_similarity(
        enrolled_embedding,
        test_embedding
    ).item()

    return {
        "verified": similarity > 0.25,
        "score": similarity
    }

@app.get("/health")
async def health_check():
    return {"status": "ready"}
```

**Swift Integration:**
```swift
class SpeakerVerificationService {
    private let baseURL = URL(string: "http://localhost:8765")!

    func verify(audioData: Data) async throws -> VerificationResult {
        var request = URLRequest(url: baseURL.appendingPathComponent("/verify"))
        request.httpMethod = "POST"
        request.setValue("audio/wav", forHTTPHeaderField: "Content-Type")
        request.httpBody = audioData

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ServiceError.requestFailed
        }

        return try JSONDecoder().decode(VerificationResult.self, from: data)
    }

    func healthCheck() async throws -> Bool {
        let (data, _) = try await URLSession.shared.data(
            from: baseURL.appendingPathComponent("/health")
        )
        let result = try JSONDecoder().decode(HealthStatus.self, from: data)
        return result.status == "ready"
    }
}
```

**Pros:**
- ✅ Model loaded once (amortize startup cost)
- ✅ Low per-request latency (~10-50ms HTTP overhead)
- ✅ Scalable - handle concurrent requests
- ✅ Easy to debug (curl, Postman)
- ✅ FastAPI: 15,000-20,000 req/sec vs Flask's 2,000-3,000
- ✅ **Total latency: ~400ms** - meets requirement

**Cons:**
- ❌ Requires service lifecycle management
- ❌ HTTP serialization overhead (base64 for audio)
- ❌ Port management considerations

#### A3. gRPC Microservice

**When to use:**
- Need ultra-low latency (<100ms overhead)
- High-throughput scenarios
- Bidirectional streaming

**Performance:**
- ~10-30ms overhead (vs 20-100ms for HTTP)
- Binary protocol, efficient serialization
- **Total latency: ~320ms** - best performance

**Tradeoff:**
- More complex setup (protobuf definitions)
- Steeper learning curve
- Less debugging tooling

### Performance Analysis

| Component | Subprocess | HTTP (FastAPI) | gRPC |
|-----------|------------|----------------|------|
| Process spawn | 50-200ms | 0ms (persistent) | 0ms |
| Python import | 100-500ms | 0ms (one-time) | 0ms |
| Model load | 500-1500ms | 0ms (one-time) | 0ms |
| Audio transfer | 10-50ms | 20-100ms | 10-30ms |
| ECAPA inference | 300ms | 300ms | 300ms |
| Result transfer | 5ms | 10-20ms | 5-10ms |
| **Total** | **965-2555ms** ❌ | **330-450ms** ✅ | **315-340ms** ✅ |

**Conclusion:**
- ❌ Subprocess: Likely fails requirement
- ✅ HTTP: Comfortably meets requirement
- ✅ gRPC: Best performance with headroom

---

## 2. Approach B: PyTorch Mobile / CoreML

### Overview

Convert Python PyTorch model to on-device format:
- **CoreML**: Apple's native ML framework (recommended for macOS)
- **ExecuTorch**: Modern PyTorch Mobile (iOS 17+, macOS 12+)
- **LibTorch**: Legacy C++ library (not recommended)

### Conversion Pipeline

```
┌──────────────┐    torch.jit.trace()    ┌─────────────┐
│ PyTorch      │ ───────────────────────▶│ TorchScript │
│ (SpeechBrain)│                         └─────────────┘
└──────────────┘                               │
                                               │ coremltools.convert()
                                               ▼
                                         ┌─────────────┐
                                         │ CoreML      │
                                         │ (.mlpackage)│
                                         └─────────────┘
                                               │
                                               ▼
                                         ┌─────────────┐
                                         │ Swift App   │
                                         │ (native)    │
                                         └─────────────┘
```

### Implementation Strategy

**Step 1: Convert ECAPA-TDNN to CoreML**

```python
import torch
import coremltools as ct
from speechbrain.inference.speaker import SpeakerRecognition

# Load model
verifier = SpeakerRecognition.from_hparams(
    source="speechbrain/spkrec-ecapa-voxceleb"
)

# Extract just the encoder
model = verifier.encode_batch.model
model.eval()

# Create example input (80 F-bank features, 300 frames)
example_input = torch.randn(1, 300, 80)

# Trace model
traced_model = torch.jit.trace(model, example_input)

# Convert to CoreML
coreml_model = ct.convert(
    traced_model,
    inputs=[ct.TensorType(shape=(1, 300, 80), name="features")]
)

# Save
coreml_model.save("SpeakerVerification.mlpackage")
```

**Step 2: Swift Integration**

```swift
import CoreML

class CoreMLSpeakerVerifier {
    private let model: SpeakerVerification
    private let enrolledEmbedding: [Float]

    init() throws {
        self.model = try SpeakerVerification(configuration: .init())
        self.enrolledEmbedding = try loadEnrolledEmbedding()
    }

    func verify(audioData: Data) throws -> VerificationResult {
        // Extract F-bank features (using Accelerate framework)
        let features = extractFBankFeatures(from: audioData)

        // Run CoreML inference
        let input = SpeakerVerificationInput(features: features)
        let output = try model.prediction(input: input)

        // Compute cosine similarity
        let similarity = cosineSimilarity(
            output.embedding,
            enrolledEmbedding
        )

        return VerificationResult(
            verified: similarity > 0.25,
            score: similarity
        )
    }
}
```

### Pros and Cons

**Pros:**
- ✅ **Best performance**: Up to 31x speedup on M1 vs PyTorch Mobile
- ✅ **Hardware acceleration**: Neural Engine + GPU (Metal)
- ✅ **Native Swift**: No bridging, first-class integration
- ✅ **Low latency**: <100ms inference on Apple Silicon
- ✅ **Battery efficient**: Neural Engine optimized for power
- ✅ **Small bundle**: ~20-40MB model size
- ✅ **Total latency: <500ms** including preprocessing

**Cons:**
- ❌ **Conversion complexity**: ECAPA-TDNN may have unsupported ops
- ❌ **Dynamic shapes**: Limited support vs PyTorch flexibility
- ❌ **Audio preprocessing**: Must implement F-bank extraction in Swift
- ❌ **Testing burden**: Need to verify accuracy matches Python
- ❌ **Initialization time**: Few seconds to load model (one-time)
- ❌ **Apple-only**: Locked to Apple ecosystem

### Conversion Challenges for ECAPA-TDNN

**Known issues:**
- Dynamic audio length handling
- Attention mechanisms compatibility
- Custom SpeechBrain operations

**Mitigation strategies:**
- Use `EnumeratedShapes` for fixed input lengths (2s, 5s, 10s)
- Pad/crop audio to standard durations
- Test conversion with sample inputs
- Consider converting only the core embedding extraction

---

## 3. Approach C: Embedded Python Interpreter

### Overview

Bundle Python runtime within Swift app, call Python via C API:
- **PythonKit**: Swift package for type-safe Python interop
- **BeeWare Python-Apple-support**: Pre-built Python frameworks
- **Direct C API**: Manual Python C API usage

### Implementation

**Bundle Structure:**
```
VoiceEverywhere.app/
├── Contents/
│   ├── Resources/
│   │   ├── python-stdlib/          # Python standard library
│   │   ├── lib-dynload/            # Dynamic libraries
│   │   └── site-packages/          # SpeechBrain, PyTorch, etc.
│   ├── Frameworks/
│   │   └── Python.xcframework      # Python runtime
│   └── MacOS/
│       └── VoiceEverywhere
```

**Swift Code:**
```swift
import PythonKit

class EmbeddedPythonVerifier {
    private let pythonQueue = DispatchQueue(
        label: "com.voiceeverywhere.python",
        qos: .userInitiated
    )

    init() {
        // Set Python paths
        let resourcePath = Bundle.main.resourcePath!
        setenv("PYTHONHOME", "\(resourcePath)/python-stdlib", 1)
        setenv("PYTHONPATH", "\(resourcePath)/python-stdlib", 1)

        // Initialize interpreter (once)
        Py_Initialize()

        // Pre-load model (on background thread)
        pythonQueue.async {
            let gstate = PyGILState_Ensure()
            // Import SpeechBrain and load model
            PyRun_SimpleString("""
                from speechbrain.inference.speaker import SpeakerRecognition
                verifier = SpeakerRecognition.from_hparams(
                    source="speechbrain/spkrec-ecapa-voxceleb"
                )
                print("Model loaded")
            """)
            PyGILState_Release(gstate)
        }
    }

    func verify(audioPath: String) async -> VerificationResult {
        await withCheckedContinuation { continuation in
            pythonQueue.async {
                let gstate = PyGILState_Ensure()

                // Call Python verification
                let result = PyRun_SimpleString("""
                    import json
                    # ... verification code ...
                    print(json.dumps({"verified": True, "score": 0.85}))
                """)

                PyGILState_Release(gstate)
                continuation.resume(returning: result)
            }
        }
    }
}
```

### Pros and Cons

**Pros:**
- ✅ Direct access to Python ecosystem
- ✅ No external service to manage
- ✅ App Store compatible
- ✅ Proven pattern in production apps

**Cons:**
- ❌ **Large bundle**: Python runtime + PyTorch + deps = 500MB-1GB
- ❌ **Initialization overhead**: 50-200ms interpreter startup
- ❌ **GIL limitations**: Single-threaded Python execution
- ❌ **Memory overhead**: ~500MB RAM for runtime + models
- ❌ **Debugging complexity**: Cross-language debugging
- ❌ **Total latency: ~1-2s** first call, ~500ms subsequent

### GIL (Global Interpreter Lock) Impact

- Only one thread can execute Python bytecode at a time
- Cannot run parallel speaker verifications
- Must serialize all Python calls through dedicated queue
- NumPy/PyTorch ops release GIL during computation (mitigates impact)

---

## Comparison Matrix

| Criterion | Subprocess | HTTP Microservice | gRPC | CoreML | Embedded Python |
|-----------|------------|-------------------|------|--------|-----------------|
| **Latency (first call)** | 2000-2500ms ❌ | 400ms ✅ | 320ms ✅ | 500ms ✅ | 1500ms ⚠️ |
| **Latency (subsequent)** | 2000-2500ms ❌ | 400ms ✅ | 320ms ✅ | 200ms ✅ | 500ms ✅ |
| **Implementation complexity** | Low | Medium | High | High | Medium |
| **Debugging** | Easy | Easy | Medium | Medium | Hard |
| **Bundle size** | Small | Small | Small | Small | Large (500MB+) |
| **Service management** | None | Required | Required | None | None |
| **Python ecosystem access** | Full | Full | Full | None | Full |
| **macOS native** | No | No | No | Yes | No |
| **Concurrency** | Multi-process | Multi-request | Multi-request | Multi-thread | GIL-limited |
| **App Store compatible** | Yes | Yes | Yes | Yes | Yes |

---

## Recommendation: HTTP Microservice (FastAPI)

### Rationale

For **STORY-001 through STORY-004 (MVP Phase 1)**, we recommend:

**Primary approach: HTTP Microservice with FastAPI**

**Why:**

1. ✅ **Meets latency requirement**: ~400ms total (well under 2s target)
2. ✅ **Low implementation risk**: Similar to existing Soniox integration pattern
3. ✅ **Easy debugging**: Can test with curl, Postman, or Python directly
4. ✅ **Flexible**: Easy to modify model, add logging, experiment with thresholds
5. ✅ **Proven**: FastAPI is production-grade with 15k+ req/sec throughput
6. ✅ **Maintains Python ecosystem**: Direct access to SpeechBrain updates
7. ✅ **Service management**: Auto-restart, health checks easy to implement

**Why not other approaches:**

- ❌ **Subprocess**: Fails latency requirement due to model reload overhead
- ⚠️ **CoreML**: High risk - ECAPA-TDNN conversion unproven, complex debugging
- ⚠️ **Embedded Python**: Large bundle, GIL limitations, harder to maintain

### Migration Path to CoreML (Phase 2 - Optional)

If performance optimization needed later:

1. Implement MVP with FastAPI
2. Collect real-world latency metrics
3. If latency becomes bottleneck (unlikely):
   - Attempt ECAPA-TDNN → CoreML conversion
   - Validate accuracy parity
   - A/B test performance
   - Migrate if successful

**Benefits of deferring CoreML:**
- Reduces risk for MVP
- Allows real-world validation of FastAPI performance
- Avoids premature optimization
- Keeps architecture flexible during feature development

---

## Implementation Strategy

### Phase 1: MVP Setup

**Step 1: Create FastAPI Service**

Directory structure:
```
voice-everywhere/
├── python-service/
│   ├── requirements.txt          # speechbrain, torch, fastapi, uvicorn
│   ├── verify_service.py         # FastAPI app
│   ├── models/                   # Downloaded models
│   └── profiles/                 # Enrolled speaker embeddings
```

**Step 2: Service Launcher in Swift**

```swift
class PythonServiceManager {
    private var process: Process?
    private let servicePort = 8765

    func start() {
        let pythonPath = "/usr/bin/python3"  // Or bundled venv
        let servicePath = Bundle.main.path(
            forResource: "verify_service",
            ofType: "py"
        )!

        process = Process()
        process?.executableURL = URL(fileURLWithPath: pythonPath)
        process?.arguments = [servicePath, "--port", "\(servicePort)"]

        // Auto-restart on crash
        process?.terminationHandler = { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self?.start()
            }
        }

        try? process?.run()

        // Wait for service ready
        Task {
            try await waitForServiceReady()
        }
    }

    func stop() {
        process?.terminate()
    }
}
```

**Step 3: Integration into VoiceController**

Add speaker verification step in state machine:

```
idle → connecting → verifying → listening → finishing → idle
```

### Phase 2: Deployment Options

**Option A: Bundled Python (Recommended)**

- Include Python venv in app bundle
- User experience: "just works"
- Bundle size: +500MB

**Option B: System Python**

- Require user to install dependencies
- Fragile (system Python version changes)
- Smaller bundle

**Option C: PyInstaller**

- Package service as standalone executable
- Include in app bundle
- Good compromise

---

## Performance Benchmarking Plan

Before full implementation, validate assumptions:

### Benchmark Tests

1. **Measure ECAPA-TDNN inference time**
   - Run 100 verifications
   - Record min/avg/max/p95 latency
   - Target: <300ms average

2. **Measure end-to-end latency**
   - Audio capture → FastAPI → result
   - Include HTTP overhead
   - Target: <500ms average

3. **Test cold start**
   - Service startup time
   - Model loading time
   - Target: <5s total

4. **Test concurrent requests**
   - Simulate multiple verifications
   - Ensure no GIL bottleneck
   - Target: 10 req/sec sustained

### Success Criteria

- ✅ Average latency < 500ms
- ✅ P95 latency < 800ms
- ✅ Startup time < 10s
- ✅ No service crashes in 1hr test
- ✅ Memory stable (<1GB RSS)

---

## Risk Analysis

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Service crashes during recording | Medium | High | Auto-restart + circuit breaker |
| Latency exceeds 2s in production | Low | Medium | Benchmark early + CoreML fallback |
| Python dependencies break | Low | Medium | Pin versions + virtual env |
| Port conflicts with other apps | Low | Low | Configurable port + retry |
| Model accuracy degrades | Low | High | Validate against Python reference |

---

## Appendix: Code Examples

### A1. Complete FastAPI Service

See: `python-service/verify_service.py` (to be created in PoC)

### A2. Swift Service Integration

See: `Sources/SpeakerVerifier.swift` (to be created in PoC)

### A3. Enrollment Flow

```python
# Enroll speaker (run once)
def enroll_speaker(audio_files: list[str], output_path: str):
    verifier = SpeakerRecognition.from_hparams(
        source="speechbrain/spkrec-ecapa-voxceleb"
    )

    embeddings = []
    for audio_file in audio_files:
        waveform, sr = torchaudio.load(audio_file)
        embedding = verifier.encode_batch(waveform)
        embeddings.append(embedding)

    # Average embeddings
    enrolled_embedding = torch.mean(torch.stack(embeddings), dim=0)
    torch.save(enrolled_embedding, output_path)
```

---

## References

### Research Sources

- [Swift Subprocess Package](https://github.com/swiftlang/swift-subprocess)
- [FastAPI Official Docs](https://fastapi.tiangolo.com/)
- [SpeechBrain ECAPA-TDNN Model](https://huggingface.co/speechbrain/spkrec-ecapa-voxceleb)
- [CoreML Tools Documentation](https://apple.github.io/coremltools/)
- [ExecuTorch on Apple Platforms](https://pytorch.org/executorch/stable/apple-runtime.html)
- [Python C API Embedding](https://docs.python.org/3/extending/embedding.html)
- [FastAPI vs Flask Performance](https://fastapi.tiangolo.com/benchmarks/)
- [Speaker Verification Best Practices](https://medium.com/@rudderanalytics/voice-based-security-implementing-a-robust-speaker-verification-system-12c5fd98f1c1)

### Related Documents

- Product Backlog: `docs/tmux/voice-team/PRODUCT_BACKLOG.md`
- Vietnamese Research: `/Users/phuhung/Documents/Notes/Hung's Notes/Research/personal-voice-recognition-noisy-environment.md`
- Project README: `CLAUDE.md`

---

**Document Status:** Draft v1.0
**Next Steps:** Create PoC demonstrating FastAPI integration
**Owner:** Coder (Swift Developer)
**Reviewer:** SM, PO
