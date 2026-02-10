# Team Whiteboard

**Sprint:** Sprint 6 ✅ CLOSED (2026-02-10)
**Goal:** Fix BUG-002 (reopened) - Spurious 'aa' from verification burst-gap pattern
**Started:** 2026-02-10
**Duration:** 10:00 → 10:26
**Boss Status:** Boss ordered close. Merged to master.

---

## Current Status

| Role | Status | Current Task | Last Update |
|------|--------|--------------|-------------|
| PO   | Done | Sprint 6 closed per Boss | 10:26 |
| SM   | Done | Sprint closed, merged to master, WHITEBOARD updated | 10:26 |
| Coder | Done | BUG-002-v2 fixed (8df8f60), merged to master | 10:26 |
| Tester | Done | Build/launch verified. Live testing deferred to Boss | 10:20 |

---

## Sprint 6 Items

### BUG-002-v2: [P0] Spurious 'aa' at Start of EVERY Speech Segment (REOPENED)
**Status:** ✅ DONE (Boss closed, merged to master 10:26)
**Assignee:** Coder
**Estimate:** 1 hour
**Priority:** P0 (Boss confirmed still broken)

**Description:** 'aa' appears NOT just at start of recording, but at the beginning of EVERY speech segment. Boss says: "start xong nói thì bị aa, xong nghỉ tẹo, nói tiếp vẫn bị aa". This means the root cause is NOT the Tink sound (which only plays once at start).

**Boss Symptom:**
1. Press hotkey → start recording → speak → 'aa' at beginning
2. Pause (stop talking for a moment)
3. Speak again → 'aa' AGAIN at beginning of new segment

**Root Cause Analysis (REVISED):**
- Sprint 5 assumed Tink sound was the cause — WRONG (or only partial cause)
- 'aa' at every speech segment = systematic issue in audio pipeline
- Likely cause if speaker verification ON: continuous verification sends 3-second chunks to Soniox (`verifyAndForwardChunk`). Each chunk arrives as a burst → Soniox interprets chunk boundaries/transitions as 'aa'
- Likely cause if speaker verification OFF: could be silence→speech transition artifacts, or audio buffer stale data
- Coder MUST check with both verification ON and OFF to isolate root cause

**Investigation Steps for Coder:**
1. Test with speaker verification DISABLED — does 'aa' still appear?
2. Test with speaker verification ENABLED — does 'aa' appear at each chunk?
3. Check SonioxStreamer logs — what tokens arrive? Are they partial or final?
4. Check if audio buffer contains stale/residual data between speech segments
5. Check Soniox WebSocket response — is 'aa' coming as a real token or artifact?

**Fix Approach (TBD after investigation):**
- If chunk-related: fix how audio is sent to Soniox (continuous stream vs burst)
- If audio buffer artifact: clear/reset buffer between speech segments
- If Soniox model artifact: filter out short 'aa' tokens at segment start
- Tink fix (150ms delay) may still be needed but is NOT the primary issue

**Acceptance Criteria:**
- [ ] No spurious 'aa' at start of ANY speech segment (not just first)
- [ ] Test: speak → pause 3s → speak again → NO 'aa' on second segment
- [ ] Test minimum 5+ recordings with pauses, 0 'aa' occurrences
- [ ] Works with speaker verification ON and OFF
- [ ] Tink sound still plays on recording start
- [ ] No noticeable delay or audio loss
- [ ] Tester black-box test passed
- [ ] Build succeeds

**Technical Notes:**
- Location: `Sources/VoiceController.swift` — continuous verification chunk logic (lines 266-277) and `verifyAndForwardChunk()` (line 374+)
- Chunk size: 3 seconds at 16kHz 16-bit (`continuousVerificationChunkSize`)
- Also check: `Sources/SonioxStreamer.swift` — how partial/final tokens handle silence gaps
- Branch: `feature_bug002_tink_ordering` (continue on this branch)

---

## Sprint Flow

```
1. PO → SM: Sprint goal + BUG-002-v2 details ← DONE
2. SM → Coder: Assign BUG-002-v2
3. Coder: Fix Tink/mic timing properly
4. Coder → SM: Done
5. SM → Tester: Black-box test (5+ recordings)
6. Tester → SM: Test results
7. SM → PO: Sprint complete
8. PO → Boss: Present for acceptance
```

---

## Today's Progress

### PO
- BUG-002 reopened by Boss (still 'aa' every recording)
- Sprint 6 created with root cause analysis (150ms delay insufficient)
- Notified SM

### SM
- 10:00: Sprint 6 received from PO. BUG-002-v2 P0.
- 10:00: Assigned to Coder. Tester on standby.
- 10:15: Coder done. Routed to Tester for black-box testing.
- 10:20: Tester blocked on live testing — escalated to PO.
- 10:25: Boss ordered close + merge to master.
- 10:26: Coder merged. Sprint 6 CLOSED.

### Coder
- 10:00: BUG-002-v2 assigned
- 10:15: DONE. Root cause: 3s burst-gap pattern from verification gating audio. Fix: parallel streaming + verification. Also fixed stale finalBuffer. Commit 8df8f60
- 10:26: Merged feature_bug002_tink_ordering to master (fast-forward). Master HEAD: 8df8f60

### Tester
- 10:00: Standing by, preparing test plan (5+ recordings with pauses, 0 'aa' target)
- 10:15: Assigned black-box testing
- 10:20: Build/launch PASSED. BLOCKED on live testing — needs Boss to perform recordings

---

## Blockers

| Role | Blocker | Reported | Status |
|------|---------|----------|--------|
| Tester | Cannot simulate hotkey/mic from tmux — live testing deferred to Boss | 10:20 | RESOLVED (Boss closed sprint) |

---

## Notes

**Sprint Context:**
- Sprint 5 fix (150ms delay) insufficient — 'aa' appears at EVERY speech segment, not just first
- Root cause is NOT Tink sound — it's a systematic audio pipeline issue
- Boss clarification: 'aa' after pauses too, not just at recording start
- Coder must investigate with verification ON/OFF to isolate
- Tester MUST verify with 5+ recordings including pauses, 0 'aa' occurrences

**Process:**
- Tester MUST test before PO acceptance (established Sprint 3)
- Tester should test minimum 5 recordings to confirm fix

---

## Previous Sprint Closures

### Sprint 6 Closure (2026-02-10 10:26)

**DELIVERED:**
- ✅ BUG-002-v2: Root cause found — verification burst-gap pattern caused 'aa' at every speech segment
- ✅ Fix: Audio streams to Soniox continuously in parallel with verification (no more gating)
- ✅ Also fixed: SonioxStreamer.finalBuffer stale data between sessions
- ✅ Merged to master (8df8f60, fast-forward)

**NOTE:**
- Tester verified build/launch but live mic testing deferred to Boss (tmux limitation)
- Trade-off: non-boss audio transcribes ~3s before detection (then stops at ~6s)

---

### Sprint 5 Closure (2026-02-06 10:56)

**DELIVERED:**
- ✅ BUG-002: Spurious 'aa' removed (commit bdbe328)
- ✅ Fix: Tink → 150ms delay → mic start
- ✅ Tester: 6/6 passed + identified theoretical race condition (deferred as enhancement)

**ACHIEVEMENTS:**
- 3rd consecutive sprint with Tester gate
- Tester adding value: identified edge case (double-press within 150ms)
- Clean, minimal fix (1 file, reorder only)

---

### Sprint 4 (2026-02-06)
- ✅ STORY-010: Transcription Storage Location config
- Tester flow: 9/9 test cases passed

### Sprint 3 (2026-02-06)
- BUG-001 fixed (transcription spacing)
- Tester role activated for first time

### Sprint 2 (2026-02-03)
- STORY-008 + STORY-009 delivered
- Boss: "Tôi thấy cũng ngon rồi"

### Sprint 1 (2026-02-03)
- 4 Phase 1 stories + 10+ fixes
- Boss: "Ngon rồi á"
