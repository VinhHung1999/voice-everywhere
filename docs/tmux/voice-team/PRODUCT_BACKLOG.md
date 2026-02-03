# Product Backlog - VoiceEverywhere

**Owner:** Product Owner (PO)
**Last Updated:** 2026-02-03

---

## Sprint Goal (Current)

**Add Speaker Recognition Feature to VoiceEverywhere**

Enable VoiceEverywhere to recognize and verify the owner's voice, filtering out other speakers and background noise.

---

## High Priority (P0-P1)

### STORY-001: [P0] Research: Swift ↔ Python Integration Architecture

**Epic:** Speaker Recognition MVP (Phase 1)

**User Story:**
As a developer, I need to understand how to integrate Python ML models (SpeechBrain + Whisper) into the Swift macOS app so that we can implement speaker verification.

**Acceptance Criteria:**
- [ ] Research 3 integration approaches:
  1. Python subprocess/microservice called from Swift
  2. PyTorch Mobile for on-device inference in Swift
  3. Python C bindings for Swift interop
- [ ] Document pros/cons of each approach
- [ ] Recommend one approach with rationale
- [ ] Create PoC (proof of concept) showing Swift calling Python code
- [ ] Document performance implications (latency, memory)

**Technical Notes:**
- Current stack: Swift/SwiftUI, Soniox WebSocket API
- Target stack: SpeechBrain (ECAPA-TDNN) + Whisper
- Constraint: Must maintain real-time performance (<2s latency)

**Estimate:** TBD by Coder

---

### STORY-002: [P0] Implement Speaker Enrollment UI

**Epic:** Speaker Recognition MVP (Phase 1)

**User Story:**
As a user, I want to enroll my voice by recording 3-5 voice samples (3-5 seconds each) so that the app can recognize my voice.

**Acceptance Criteria:**
- [ ] Add "Voice Enrollment" section to Settings window
- [ ] UI for recording 3-5 voice samples
- [ ] Display recording progress (time, sample count)
- [ ] Visual feedback during recording
- [ ] Save samples to disk (WAV format, 16kHz)
- [ ] Show enrollment status (not enrolled / enrolled)
- [ ] Allow re-enrollment (overwrite existing profile)

**Technical Notes:**
- Reuse AudioCapture.swift for recording
- Save to ~/Library/Application Support/VoiceEverywhere/voice_profile/
- Format: WAV, 16kHz, mono (same as existing audio pipeline)

**Estimate:** TBD by Coder

---

### STORY-003: [P0] Implement Speaker Verification Backend

**Epic:** Speaker Recognition MVP (Phase 1)

**User Story:**
As the system, I need to verify incoming audio against the enrolled voice profile so that I only process the owner's voice.

**Acceptance Criteria:**
- [ ] Integrate SpeechBrain ECAPA-TDNN model
- [ ] Load enrolled voice samples and create embedding
- [ ] Implement real-time verification during recording
- [ ] Return similarity score and accept/reject decision
- [ ] Use threshold 0.25 as starting point
- [ ] Log verification results for tuning

**Technical Notes:**
- Depends on STORY-001 (architecture decision)
- Model: `speechbrain/spkrec-ecapa-voxceleb`
- Input: 16kHz PCM audio chunks
- Output: bool (is_owner) + float (similarity_score)

**Estimate:** TBD by Coder

---

### STORY-004: [P1] Integrate Speaker Verification into Voice Pipeline

**Epic:** Speaker Recognition MVP (Phase 1)

**User Story:**
As a user, when I record voice input, the app should only transcribe my voice and ignore other speakers.

**Acceptance Criteria:**
- [ ] Insert speaker verification step before Soniox transcription
- [ ] If verification fails, discard audio chunk (don't send to Soniox)
- [ ] Show verification status in menubar (icon badge or tooltip)
- [ ] Add setting to enable/disable speaker verification
- [ ] Update error handling for verification failures
- [ ] Log verification scores for debugging

**Technical Notes:**
- Modify VoiceController.swift state machine
- Add state: `idle → connecting → verifying → listening → finishing`
- May need to buffer audio for verification before streaming

**Estimate:** TBD by Coder

---

## Medium Priority (P2)

### STORY-005: [P2] Add Threshold Tuning UI

**Epic:** Speaker Recognition MVP (Phase 1)

**User Story:**
As a user, I want to adjust the verification threshold so that I can balance between false positives and false negatives.

**Acceptance Criteria:**
- [ ] Add threshold slider in Settings (range 0.1-0.5)
- [ ] Show current threshold value
- [ ] Add "Test Verification" button to test current threshold
- [ ] Display recent verification scores
- [ ] Save threshold to UserDefaults
- [ ] Default: 0.25

**Estimate:** TBD by Coder

---

## High Priority (P1) - Phase 2: Continuous Verification

### STORY-008: [P1] Continuous Speaker Verification During Recording

**Epic:** Speaker Recognition Phase 2 - Real-time Filtering

**User Story:**
As a user, I want the app to continuously verify my voice throughout the recording, not just at the start, so that if someone else speaks during my recording, their voice is filtered out.

**Boss Requirement:**
"Tôi muốn nó verify kiểu liên tục trong lúc tôi nói vậy nè. Để mà có những cái người mà nói vào á thì nó sẽ lọc cái chỗ đó ra."

**Acceptance Criteria:**
- [ ] Verify speaker on each speech segment (NOT just at recording start)
- [ ] Segmentation: 1-second audio chunks OR Voice Activity Detection
- [ ] Continue buffering and verifying throughout entire recording
- [ ] Performance: <20ms verification per segment (maintain current speed)
- [ ] Log all verification results with timestamps
- [ ] Handle state: verifying → listening → verifying (continuous loop)

**Technical Notes:**
- Modify VoiceController.swift state machine for continuous verification
- Add audio segmentation logic (1s chunks recommended)
- Queue-based architecture: segment → verify → forward if verified
- Maintain Soniox connection during pauses

**Dependencies:** STORY-004 (completed)

**Estimate:** TBD by Coder

---

### STORY-009: [P1] Real-time Speaker Filtering with Pause/Resume

**Epic:** Speaker Recognition Phase 2 - Real-time Filtering

**User Story:**
As a user, when someone else's voice is detected during my recording, the app should pause transcription and resume only when my voice returns, so that only my words are transcribed.

**Boss Requirement:**
"Pause và resume khi lại là giọng boss"

**Acceptance Criteria:**
- [ ] When non-Boss voice detected (score < threshold):
  - Pause Soniox streaming (don't send audio)
  - Buffer incoming audio
  - Continue verification on buffered segments
- [ ] When Boss voice detected again (score > threshold):
  - Resume Soniox streaming
  - Send buffered Boss segments
- [ ] Maintain transcription continuity (no text gaps from user perspective)
- [ ] Visual feedback: menubar icon shows pause/resume state
- [ ] Handle rapid speaker changes (debouncing if needed)

**Technical Notes:**
- Implement Soniox pause/resume logic (may need to close/reopen connection)
- Audio buffer management for segments awaiting verification
- State machine: listening → paused (non-Boss) → listening (Boss returns)
- Consider: Send silence to Soniox vs. actual pause?

**Dependencies:** STORY-008

**Estimate:** TBD by Coder

---

## Medium Priority (P2)

### STORY-005: [P2] Add Threshold Tuning UI

**Status:** COMPLETED (threshold API exists, can set via curl)

---

## Future (P3) - Phase 3: Noise Handling

### STORY-006: [P3] Add Speech Enhancement for Noisy Environments

**User Story:**
As a user, I want the app to work in noisy environments by filtering out background noise before verification.

**Technical Notes:**
- Integrate SepFormer or FullSubNet
- Add pre-processing step before speaker verification
- Test in real-world noisy environments

**Status:** Backlog (Phase 2)

---

### STORY-007: [P3] Optimize Real-time Streaming Pipeline

**User Story:**
As a user, I want the speaker verification to work in real-time without noticeable latency.

**Technical Notes:**
- Target: <1.5s end-to-end latency
- Optimize model inference
- Consider edge deployment options

**Status:** Backlog (Phase 3)

---

## Definition of Done

A Story is "Done" when:
- [ ] All acceptance criteria met
- [ ] Code implemented and committed
- [ ] Tests pass (unit tests if applicable)
- [ ] Tester black-box testing passed
- [ ] Build succeeds (`./scripts/build_app.sh`)
- [ ] PO accepts

---

## Notes

**Key Technical Decisions Pending:**
1. Swift ↔ Python integration architecture (STORY-001)
2. Real-time verification latency impact on UX

**References:**
- Research doc: `/Users/phuhung/Documents/Notes/Hung's Notes/Research/personal-voice-recognition-noisy-environment.md`
- SpeechBrain ECAPA-TDNN: https://huggingface.co/speechbrain/spkrec-ecapa-voxceleb
