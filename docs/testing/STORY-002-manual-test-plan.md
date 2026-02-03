# STORY-002 Manual Test Plan: Speaker Enrollment UI

**Story:** STORY-002 [P0] Implement Speaker Enrollment UI
**Date:** 2026-02-03
**Tester:** QA Team

---

## Prerequisites

1. Build and launch VoiceEverywhere app:
   ```bash
   ./scripts/build_app.sh
   open dist/VoiceEverywhere.app
   ```

2. Grant microphone permission when prompted

3. Open Settings window (click menubar icon → Settings)

---

## Test Cases

### TC1: Initial State - Not Enrolled

**Steps:**
1. Open Settings window
2. Scroll to "Voice Enrollment" section

**Expected:**
- Section header: "Voice Enrollment"
- Status label: "Not enrolled"
- Button: "Record Sample 1/5" (enabled)
- Progress label: (empty)
- "Clear & Re-enroll" button (disabled)

**Result:** ☐ Pass ☐ Fail

---

### TC2: Record First Sample

**Steps:**
1. Click "Record Sample 1/5"
2. Speak into microphone for 3-5 seconds
3. Observe UI during recording
4. Click "Stop Recording" or wait 5 seconds

**Expected During Recording:**
- Button changes to "Stop Recording"
- Progress label shows: "Recording: X.Xs / 5.0s" (updating every 0.1s)
- Save button disabled
- Clear button disabled
- Auto-stops at 5.0 seconds if not manually stopped

**Expected After Recording:**
- Beep sound played at start and stop
- Status label updates: "Enrolled (1 samples)"
- Button text: "Record Sample 2/5"
- Progress label: "✓ 1 samples recorded"
- Save button re-enabled
- File saved: ~/Library/Application Support/VoiceEverywhere/voice_profile/sample_1.wav

**Result:** ☐ Pass ☐ Fail

---

### TC3: Record Additional Samples (2-5)

**Steps:**
1. Repeat TC2 for samples 2, 3, 4, 5
2. Check button text updates: 2/5, 3/5, 4/5, 5/5
3. Check status updates: "Enrolled (2 samples)", etc.

**Expected:**
- Each recording creates a new file (sample_2.wav, sample_3.wav, etc.)
- Button disabled after 5th sample
- All samples saved to voice_profile directory

**Result:** ☐ Pass ☐ Fail

---

### TC4: Verify WAV Files

**Steps:**
1. Navigate to: ~/Library/Application Support/VoiceEverywhere/voice_profile/
2. List files: `ls -lh`
3. Check file properties: `file sample_1.wav`
4. Test playback: `afplay sample_1.wav`

**Expected:**
- 5 files: sample_1.wav through sample_5.wav
- File type: WAVE audio, 16000 Hz, mono
- File size: ~3-5 seconds * 16000 * 2 bytes = 96KB-160KB per file
- Playback works and contains recorded voice

**Result:** ☐ Pass ☐ Fail

---

### TC5: Clear Enrollment

**Steps:**
1. Click "Clear & Re-enroll" button
2. Confirm dialog appears
3. Click "Clear"

**Expected:**
- Confirmation dialog: "Clear Voice Enrollment?" with warning text
- After confirmation:
  - Status: "Not enrolled"
  - Button: "Record Sample 1/5" (enabled)
  - Progress: "Enrollment cleared"
  - All WAV files deleted from voice_profile directory

**Result:** ☐ Pass ☐ Fail

---

### TC6: Re-enrollment After Clear

**Steps:**
1. After clearing, record 3 new samples
2. Verify new files created

**Expected:**
- Can re-enroll successfully
- New samples overwrite old ones
- Status shows correct count

**Result:** ☐ Pass ☐ Fail

---

### TC7: Cancel Recording (Edge Case)

**Steps:**
1. Start recording (click "Record Sample X/5")
2. Immediately close Settings window without stopping

**Expected:**
- Recording cancelled automatically
- No partial file saved
- UI returns to ready state on reopen

**Result:** ☐ Pass ☐ Fail

---

### TC8: Recording Too Short (Edge Case)

**Steps:**
1. Start recording
2. Stop after < 1 second

**Expected:**
- File still saved (any duration accepted)
- Minimum recommended: 3 seconds for enrollment quality
- Note: Backend validation will happen in STORY-003

**Result:** ☐ Pass ☐ Fail

---

### TC9: Microphone Permission Denied

**Steps:**
1. Deny microphone permission in System Settings
2. Try to record sample

**Expected:**
- Error alert: "Failed to start recording: Mic permission denied"
- No crash
- UI remains functional

**Result:** ☐ Pass ☐ Fail

---

### TC10: Visual Feedback & UX

**Steps:**
1. Observe UI styling and layout
2. Check alignment with existing Settings sections

**Expected:**
- Section matches existing style (same font, spacing)
- Separator line before Voice Enrollment
- No overlapping elements
- Window height: 750px (increased from 600px)
- All elements visible without scrolling

**Result:** ☐ Pass ☐ Fail

---

## Automated Verification

Run WAV file creation test:
```bash
swift /private/tmp/claude-501/scratchpad/test_enrollment.swift
```

**Expected:**
- 3 test files created
- afplay verification passes
- File size ~96KB per file

---

## Acceptance Criteria Checklist

Based on STORY-002 acceptance criteria:

- [ ] 1. Add 'Voice Enrollment' section to Settings window ✓
- [ ] 2. UI for recording 3-5 voice samples (3-5 seconds each) ✓
- [ ] 3. Display recording progress (time, sample count) ✓
- [ ] 4. Visual feedback during recording ✓
- [ ] 5. Save samples to disk (WAV, 16kHz) at ~/Library/.../voice_profile/ ✓
- [ ] 6. Show enrollment status (not enrolled / enrolled) ✓
- [ ] 7. Allow re-enrollment (overwrite existing profile) ✓

---

## Issues Found

| Issue | Severity | Description | Status |
|-------|----------|-------------|--------|
| | | | |

---

## Notes

- Recording uses existing AudioCapture.swift (same audio pipeline as main feature)
- WAV format: PCM signed 16-bit LE, 16kHz, mono (matches Soniox API requirements)
- EnrollmentManager handles all file I/O
- Settings window expanded from 600px to 750px height

---

## Sign-off

**Coder:** Implemented and unit-tested ✓ (2026-02-03)
**Tester:** ☐ Black-box tested
**PO:** ☐ Accepted

---

## Related Files

- Implementation: `Sources/EnrollmentManager.swift`
- UI: `Sources/ContextConfigWindow.swift` (lines 52-63, 80-85, 227-258, 441-541)
- Test: `/private/tmp/claude-501/scratchpad/test_enrollment.swift`
