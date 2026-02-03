# Team Whiteboard

**Sprint:** Sprint 2 🚀 IN PROGRESS
**Goal:** Continuous Speaker Verification & Real-time Filtering
**Started:** 2026-02-03 13:50

---

## Current Status

| Role | Status | Current Task | Last Update |
|------|--------|--------------|-------------|
| PO   | Active | Sprint 2 planning complete | 13:50 |
| SM   | Active | Coordinating feasibility assessment | 13:50 |
| Coder | Done | STORY-008 complete (077a4a5) | 14:00 |
| Tester | Idle   | Not initialized | - |

---

## Sprint 2 Stories

### STORY-008: [P1] Continuous Speaker Verification During Recording
**Status:** 🚀 IN PROGRESS (Approved by Boss 13:55)
**Assignee:** Coder
**Estimate:** 11 hours
**Description:** Verify speaker continuously (every 1s segment), not just at start
**Boss Requirement:** "Verify kiểu liên tục trong lúc tôi nói"
**Technical Approach:** Fixed 1s chunks, async verification

### STORY-009: [P1] Real-time Speaker Filtering with Pause/Resume
**Status:** 📋 TODO (Blocked by STORY-008)
**Assignee:** Coder
**Estimate:** 8 hours
**Description:** Pause transcription when non-Boss voice detected, auto-resume when Boss returns
**Boss Requirement:** "Pause và resume khi lại là giọng boss"
**Boss Clarification:** NO need to press hotkey again - auto resume!

---

## Today's Progress

### PO
- 13:50: Created STORY-008 and STORY-009 in PRODUCT_BACKLOG.md
- 13:50: Sprint 2 planning complete
- 13:50: Awaiting team estimates and technical assessment

### Coder
- [Awaiting Sprint 2 kickoff]

### SM
- [Awaiting Sprint 2 kickoff]

---

## Blockers

| Role | Blocker | Reported | Status |
|------|---------|----------|--------|
| - | No blockers yet | - | - |

---

## Technical Questions for Coder

1. **Segmentation approach:** VAD-based or fixed 1s chunks?
2. **Soniox pause/resume:** Close/reopen connection or send silence?
3. **Buffer management:** How to queue segments awaiting verification?
4. **Performance impact:** Estimate overhead of continuous verification
5. **Feasibility:** Can we achieve pause/resume without breaking transcription?

---

## Notes

**Sprint 2 Context:**
- Boss approved Phase 1 MVP: "Ngon rồi á"
- Sprint 1 delivered: 4/4 stories, 10+ fixes
- Sprint 2 focus: Real-time continuous verification (more complex!)

**Key Architecture Questions:**
- How to segment audio for continuous verification?
- How to maintain Soniox connection during pauses?
- Performance: Can we verify every 1s without lag?

**Boss Clarifications:**
- Verify frequency: "Mỗi script nói" (each speech segment)
- Behavior: Pause when non-Boss, resume when Boss returns
- Threshold: 0.35 (tuned in Sprint 1)

---

## Sprint 1 Closure (2026-02-03 13:45)

**DELIVERED:**
- ✅ All 4 Phase 1 stories completed and accepted
- ✅ 10+ critical fixes applied
- ✅ Boss tested and approved ("Ngon rồi á")
- ✅ Performance: <20ms verification latency
- ✅ Threshold tuned to 0.35

---

## Clear After Sprint

After Sprint Review and Retrospective, clear this whiteboard for next Sprint.
Keep only the template structure.
