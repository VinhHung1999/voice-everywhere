# Retrospective Log

**Purpose:** Historical record of retrospectives and lessons learned.

---

## Sprint 1 Retrospective

**Date:** 2026-02-03
**Duration:** Quick (no major issues)

### Active Improvement Check
- Previous: N/A (first sprint)
- Status: N/A

### What Went Well
- Clear, unambiguous acceptance criteria (PO)
- Research phase (STORY-001) de-risked subsequent implementation
- Incremental delivery: architecture → enrollment → backend → integration
- All stories accepted on first review (100% first-time acceptance)
- Team executed autonomously with minimal clarification needed
- Coder quality consistently high, comprehensive documentation
- SM coordination kept workflow smooth
- Communication flow worked well: PO ↔ SM ↔ Coder
- Build success rate: 100%
- Technical debt: minimal

### What Could Be Improved
- Tester role unused (direct PO acceptance) - consider for Phase 2
- No integration testing performed (deferred to manual testing)

### Selected for Next Sprint (1-2 max)
- None needed - process working well

### Not Selected (For Future)
- Consider initializing Tester for Phase 2 stories with more complex testing needs

### Prompt Updates
- None (process working effectively)

### Sprint 1 Metrics
| Metric | Value |
|--------|-------|
| Stories Completed | 4/4 (100%) |
| First-time Acceptance | 100% |
| Build Success | 100% |
| Initial Velocity | 27 minutes |
| Bug Fixes Applied | 10+ commits |
| Boss Approval | "Ngon rồi á" ✅ |

### Post-MVP Bug Fixes (Critical)
| Issue | Commit | Resolution |
|-------|--------|------------|
| torch/torchaudio versions | 1f91f7b | Pin to 2.8.0 |
| setup.sh ignoring requirements | 2792f6d | Use -r requirements.txt |
| Missing requests dep | 6d3d8bc | Added to requirements |
| huggingface_hub API | 2d13d1a | Pin <1.0 |
| Missing enroll button | 61e129e | Added UI button |
| soundfile backend | 89a4514 | Added dependency |
| Settings no scroll | e855fda | NSScrollView added |
| cosine_similarity 3D tensors | f143ecb | view(1,-1) flatten |
| First 2s audio lost | ee2de67 | Send buffer to Soniox |

### Key Learnings
1. **Dependency management is critical** - Pin ALL versions explicitly
2. **Debug logging pays off** - 3D tensor issue found via extensive logs
3. **Test on clean install** - setup.sh bug only found on fresh venv
4. **Complete workflow testing** - Enrollment button gap found during E2E test

---

## Template for Future Sprints

```markdown
## Sprint N Retrospective

**Date:** YYYY-MM-DD
**Duration:** [X] min (Quick/Full)

### Active Improvement Check
- Previous: [What we were working on]
- Status: Effective / Still monitoring / Not working

### What Went Well
- [List items]

### What Could Be Improved
- [List items]

### Selected for This Sprint (1-2 max)
- [OBS-XXX]: [Description]

### Not Selected (For Future)
- [OBS-YYY]: Lower priority, revisit Sprint N+2

### Prompt Updates
- None (no recurring issues)
OR
- Updated `[file]`: [minimal change]
```
