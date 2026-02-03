# VoiceEverywhere Team

<context>
A Scrum-based multi-agent team for VoiceEverywhere - a native macOS menubar app that captures voice input and converts it to text using Soniox API, with optional LLM post-processing via xAI API.
</context>

**Project:** VoiceEverywhere - macOS voice-to-text menubar app
**Stack:** Swift/SwiftUI, Carbon framework (hotkeys), WebSocket (Soniox API), REST (xAI API)
**Working Directory:** /Users/phuhung/Documents/Studies/AIProjects/voice-everywhere

---

## Team Roles

| Role | Pane | Purpose |
|------|------|---------|
| PO | 0 | Product Owner - Backlog management, priorities, stakeholder liaison |
| SM | 1 | Scrum Master - Team effectiveness, process improvement |
| Coder | 2 | Swift Developer - Implementation with TDD |
| Tester | 3 | QA - Black-box testing, quality validation |
| Boss | Outside | Sprint goals, feedback, acceptance |

---

## CRITICAL: Pane Detection (Common Bug)

**When initializing roles or detecting which pane you're in:**

**NEVER use `tmux display-message -p '#{pane_index}'`** - this returns the ACTIVE/FOCUSED pane (where user's cursor is), NOT your pane!

**Always use `$TMUX_PANE` environment variable:**

```bash
# WRONG - Returns active cursor pane
tmux display-message -p '#{pane_index}'

# CORRECT - Returns YOUR pane
echo $TMUX_PANE
tmux list-panes -a -F '#{pane_id} #{pane_index} #{@role_name}' | grep $TMUX_PANE
```

---

## Communication Protocol

### Use tm-send for ALL Messages

```bash
# Correct
tm-send SM "Coder [HH:mm]: Task complete. Tests passing."

# Forbidden
tmux send-keys -t %16 "message" C-m C-m  # NEVER!
```

### Communication Patterns

| From | To | When |
|------|-----|------|
| Boss | PO | Sprint goals, priorities, feedback |
| PO | SM | Backlog updates, priority changes |
| SM | Coder, Tester | Sprint coordination |
| Coder | SM | Task completion, blockers |
| Tester | SM | Testing results, quality issues |

**SM is the communication hub for process. All dev communication goes through SM.**

---

## Sprint Workflow

### Phase 1: Sprint Planning

```
Boss → PO: Sprint Goal
PO → SM: Backlog items for Sprint
SM → Coder: Sprint assignment
```

### Phase 2: Sprint Execution

```
1. Coder implements with TDD (XCTest framework)
2. Coder commits progressively
3. SM monitors progress
4. PO available for clarifications
5. When Coder done → SM assigns to Tester
6. Tester performs black-box testing
```

### Phase 3: Sprint Review

```
Tester → SM: Test results
SM → PO: Sprint complete
PO → Boss: Present for acceptance
```

### Phase 4: Sprint Retrospective

```
SM reviews process issues
SM picks 1-2 improvements
SM updates prompts if needed
```

---

## Project-Specific Knowledge

### Key Files

| File | Purpose |
|------|---------|
| Sources/AppMain.swift | SwiftUI @main entry point |
| Sources/AppDelegate.swift | Menubar UI (NSStatusItem) |
| Sources/VoiceController.swift | State machine, orchestration |
| Sources/SonioxStreamer.swift | WebSocket to Soniox API |
| Sources/AudioCapture.swift | AVAudioEngine setup |
| Sources/TextInjector.swift | Accessibility API keyboard simulation |
| Sources/LLMProcessor.swift | xAI API for post-processing |
| Sources/ContextConfigWindow.swift | Settings UI |

### Build Commands

```bash
# Build release
./scripts/build_app.sh

# Build debug
./scripts/build_app.sh debug

# Run app
open dist/VoiceEverywhere.app
```

### Testing Approach

- **Unit tests:** XCTest framework (Swift)
- **Manual testing:** Test on macOS with microphone
- **Black-box testing:** Test as user (hotkey, voice, settings)

### Required macOS Permissions

1. Microphone Access
2. Accessibility (for TextInjector)

---

## Definition of Done

A Story is "Done" when:
- [ ] Code implemented and committed
- [ ] Tests pass (if applicable)
- [ ] Code reviewed by Coder self-review
- [ ] Tester black-box testing passed
- [ ] Build succeeds (`./scripts/build_app.sh`)
- [ ] PO accepts

---

## Git Workflow

```bash
# Feature branch
git checkout -b feature_{story_id}_{description}

# After testing passes
git checkout master
git merge feature_{story_id}_{description}
```

---

## Files in This Directory

```
voice-team/
├── workflow.md           # This file
├── WHITEBOARD.md         # Sprint status
├── sm/                   # SM's workspace
│   ├── IMPROVEMENT_BACKLOG.md
│   └── RETROSPECTIVE_LOG.md
└── prompts/
    ├── PO_PROMPT.md      # Product Owner
    ├── SM_PROMPT.md      # Scrum Master
    ├── Coder_PROMPT.md   # Swift Developer
    └── Tester_PROMPT.md  # QA Tester
```

---

## Common Mistakes to Avoid

| Mistake | Correct Approach |
|---------|------------------|
| Using `tmux send-keys` | Use `tm-send ROLE "message"` |
| Skipping tests | Write tests when applicable |
| Not reporting completion | Always report via tm-send |
| Direct PO → Coder | All dev communication through SM |
