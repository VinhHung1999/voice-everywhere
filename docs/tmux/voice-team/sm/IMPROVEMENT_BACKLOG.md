# Scrum Master's Improvement Backlog

**Owner:** Scrum Master (SM)
**Purpose:** Track process issues for retrospective discussion. Only 1-2 become action items per Sprint.

---

## How This Works

1. **During Sprint**: SM observes issues and logs them here (don't stop work)
2. **At Retrospective**: Team reviews and **picks 1-2** to action (not all)
3. **Unpicked items**: Stay here for future Sprints
4. **Some items**: May become irrelevant or superseded over time

---

## Active Improvement (Current Sprint)

**From:** Sprint [N] Retrospective
**Action Item:** [The 1-2 items selected]

### Verification Criteria
- **Observable behavior:** [What specific action should team take?]
- **Trigger situation:** [When should this behavior occur?]
- **Expected frequency:** [How often will this situation arise?]

### Sprint Start Announcement
- [ ] Broadcasted to all roles at Sprint start

### Evidence Log (During Sprint)

| Date | Situation | Role | Followed? | Notes |
|------|-----------|------|-----------|-------|
| | [What happened] | Coder | Y/N | [Reminded? Evidence?] |

### Sprint End Verification

| Metric | Count |
|--------|-------|
| Situations observed | |
| Followed without reminder | |
| Needed reminder | |
| **Status** | Effective / Still monitoring / Not working |

---

## Observed (Not Yet Discussed)

*SM logs issues here during sprint. Don't stop work - just note and continue.*

| ID | Date | Observation | Source | Impact |
|----|------|-------------|--------|--------|
| OBS-001 | 2026-02-03 | Tester idle entire project - UI bugs reached Boss | Boss feedback | HIGH |
| OBS-002 | 2026-02-03 | Missing scroll, hidden buttons caused rework | Sprint 1 bugs | HIGH |

---

## CRITICAL: Boss Feedback (2026-02-03)

**Boss Message:** "Be Better next time"
**Issue:** "tốn thời gian vcl" - wasted time on rework

**Root Cause:**
- Tester was never initialized
- UI bugs (scroll, buttons) reached Boss testing
- Multiple fix cycles for UI issues

**Corrective Action (MANDATORY for next project):**
1. ✅ Initialize Tester agent from Sprint 1
2. ✅ Tester MUST test UI/UX before PO acceptance
3. ✅ Block story acceptance if UI bugs found
4. ✅ Tester reports to SM/Coder BEFORE PO sees it

**Documentation Created:**
- docs/tmux/voice-team/TESTER_ROLE.md
- UI testing checklist
- Bug reporting protocol

---

## Discussed (Reviewed at Retro, Not Selected)

*Items reviewed but not prioritized. May be selected in future sprint.*

| ID | Observation | Discussed | Why Not Selected |
|----|-------------|-----------|------------------|
| | | Sprint N | Lower priority than OBS-XXX |

---

## Completed

*Action items that were implemented and verified effective.*

| ID | Observation | Sprint Selected | Sprint Completed | Prompt Updated? |
|----|-------------|-----------------|------------------|-----------------|
| | | | | Yes/No |

---

## Guidelines

### When to Log (for SM)
- Team member reports frustration
- Same issue occurs twice
- Process causes confusion
- Handoff problems between Coder/Tester
- Communication breakdowns

### When NOT to Log
- One-time mistakes
- Issues that self-correct
- Technical bugs (those are for Tester to find)

### Prompt Hygiene Rules
- **Add to prompt**: Only after 2-3 sprints of recurring issues
- **Remove from prompt**: When behavior is learned (no issues for 3+ sprints)
- **Goal**: Prompts should "work themselves out of a job"
