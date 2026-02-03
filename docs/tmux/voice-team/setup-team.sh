#!/bin/bash

# VoiceEverywhere Team - Automated Setup Script
# Creates a tmux session with 4 Claude Code instances (PO, SM, Coder, Tester)

set -e  # Exit on error

PROJECT_ROOT="${PROJECT_ROOT:-/Users/phuhung/Documents/Studies/AIProjects/voice-everywhere}"
SESSION_NAME="${SESSION_NAME:-voice_team}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROMPTS_DIR="$SCRIPT_DIR/prompts"

echo "Starting VoiceEverywhere Team Setup..."
echo "Project Root: $PROJECT_ROOT"
echo "Session Name: $SESSION_NAME"

# 1. Check if session already exists
if tmux has-session -t $SESSION_NAME 2>/dev/null; then
    echo "Session '$SESSION_NAME' already exists!"
    read -p "Kill existing session and create new one? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        tmux kill-session -t $SESSION_NAME
        echo "Killed existing session"
    else
        echo "Aborted. Use 'tmux attach -t $SESSION_NAME' to attach"
        exit 0
    fi
fi

# 2. Start new tmux session
echo "Creating tmux session '$SESSION_NAME'..."
cd "$PROJECT_ROOT"
tmux new-session -d -s $SESSION_NAME

# 3. Create 4-pane layout
echo "Creating 4-pane layout..."
tmux split-window -h -t $SESSION_NAME
tmux split-window -h -t $SESSION_NAME
tmux split-window -h -t $SESSION_NAME
tmux select-layout -t $SESSION_NAME even-horizontal

# 4. Resize for proper pane widths
echo "Resizing window..."
tmux resize-window -t $SESSION_NAME -x 480 -y 50

# 5. Set pane titles and role names
tmux select-pane -t $SESSION_NAME:0.0 -T "PO"
tmux select-pane -t $SESSION_NAME:0.1 -T "SM"
tmux select-pane -t $SESSION_NAME:0.2 -T "Coder"
tmux select-pane -t $SESSION_NAME:0.3 -T "Tester"

tmux set-option -p -t $SESSION_NAME:0.0 @role_name "PO"
tmux set-option -p -t $SESSION_NAME:0.1 @role_name "SM"
tmux set-option -p -t $SESSION_NAME:0.2 @role_name "Coder"
tmux set-option -p -t $SESSION_NAME:0.3 @role_name "Tester"

# 6. Get pane IDs
echo "Getting pane IDs..."
PANE_IDS=$(tmux list-panes -t $SESSION_NAME -F "#{pane_id}")
PO_PANE=$(echo "$PANE_IDS" | sed -n '1p')
SM_PANE=$(echo "$PANE_IDS" | sed -n '2p')
CODER_PANE=$(echo "$PANE_IDS" | sed -n '3p')
TESTER_PANE=$(echo "$PANE_IDS" | sed -n '4p')

echo "Pane IDs:"
echo "  PO (Pane 0): $PO_PANE"
echo "  SM (Pane 1): $SM_PANE"
echo "  Coder (Pane 2): $CODER_PANE"
echo "  Tester (Pane 3): $TESTER_PANE"

# 7. Verify tm-send is installed globally
echo "Verifying tm-send installation..."

if command -v tm-send >/dev/null 2>&1; then
    echo "tm-send is installed at: $(which tm-send)"
else
    echo ""
    echo "ERROR: tm-send is not installed!"
    echo ""
    echo "tm-send is a GLOBAL tool that must be installed to ~/.local/bin/tm-send"
    echo "It is NOT project-specific - one installation serves all projects."
    echo ""
    echo "Install it first, then re-run this script."
    echo ""
    exit 1
fi

# 8. Verify SessionStart hook is configured
echo "Verifying SessionStart hook..."
HOOK_FILE="$PROJECT_ROOT/.claude/hooks/session_start_team_docs.sh"
SETTINGS_FILE="$PROJECT_ROOT/.claude/settings.json"

if [ ! -f "$HOOK_FILE" ]; then
    echo ""
    echo "WARNING: SessionStart hook not found at $HOOK_FILE"
    echo "Without this hook, agents will lose context after auto-compact!"
    echo ""
fi

if [ ! -f "$SETTINGS_FILE" ]; then
    echo "WARNING: .claude/settings.json not found"
    echo "SessionStart hook may not be configured."
    echo ""
fi

# 9. Start Claude Code in each pane with model assignment
# Model assignment:
#   SM = Opus (high-level coordination)
#   PO = Sonnet (product decisions)
#   Coder = Sonnet (implementation)
#   Tester = Haiku (testing tasks)
echo "Starting Claude Code in all panes..."

# PO - Sonnet
tmux send-keys -t $SESSION_NAME:0.0 "cd $PROJECT_ROOT && claude --model sonnet" C-m

# SM - Opus (Scrum Master needs high reasoning for coordination)
tmux send-keys -t $SESSION_NAME:0.1 "cd $PROJECT_ROOT && claude --model opus" C-m

# Coder - Sonnet
tmux send-keys -t $SESSION_NAME:0.2 "cd $PROJECT_ROOT && claude --model sonnet" C-m

# Tester - Haiku (testing tasks)
tmux send-keys -t $SESSION_NAME:0.3 "cd $PROJECT_ROOT && claude --model haiku" C-m

# 10. Wait for Claude Code to start
echo "Waiting 20 seconds for Claude Code instances..."
sleep 20

# 11. Initialize roles (Two-Enter Rule + 0.3s sleep to avoid race condition)
echo "Initializing agent roles..."
tmux send-keys -t $SESSION_NAME:0.0 "/init-role PO" C-m
sleep 0.3
tmux send-keys -t $SESSION_NAME:0.0 C-m
sleep 2
tmux send-keys -t $SESSION_NAME:0.1 "/init-role SM" C-m
sleep 0.3
tmux send-keys -t $SESSION_NAME:0.1 C-m
sleep 2
tmux send-keys -t $SESSION_NAME:0.2 "/init-role Coder" C-m
sleep 0.3
tmux send-keys -t $SESSION_NAME:0.2 C-m
sleep 2
tmux send-keys -t $SESSION_NAME:0.3 "/init-role Tester" C-m
sleep 0.3
tmux send-keys -t $SESSION_NAME:0.3 C-m

# 12. Wait for initialization
echo "Waiting 15 seconds for role initialization..."
sleep 15

# 13. Summary
echo ""
echo "Setup Complete!"
echo ""
echo "Session: $SESSION_NAME"
echo "Project: $PROJECT_ROOT"
echo ""
echo "VoiceEverywhere Team Roles:"
echo "  +--------+--------+--------+--------+"
echo "  | PO     | SM     | Coder  | Tester |"
echo "  | Pane 0 | Pane 1 | Pane 2 | Pane 3 |"
echo "  +--------+--------+--------+--------+"
echo ""
echo "Role Responsibilities:"
echo "  - PO: Product Owner (backlog, priorities)"
echo "  - SM: Scrum Master (process, coordination)"
echo "  - Coder: Swift Developer (implementation)"
echo "  - Tester: QA (black-box testing)"
echo ""
echo "Next steps:"
echo "  1. Attach: tmux attach -t $SESSION_NAME"
echo "  2. Boss provides Sprint Goal to PO via: >>> [message]"
echo "  3. Team executes Sprint"
echo "  4. SM facilitates Retrospective"
echo ""
echo "To detach: Ctrl+B, then D"
echo "To kill: tmux kill-session -t $SESSION_NAME"
echo ""

# 14. Move cursor to PO pane
tmux select-pane -t $SESSION_NAME:0.0
echo "Cursor in Pane 0 (PO)."
