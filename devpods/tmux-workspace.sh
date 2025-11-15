#!/bin/bash
set -e  # Exit on error, but not verbose

# Get the directory where this script is located
readonly DEVPOD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Set defaults for environment variables if not set
: "${WORKSPACE_FOLDER:=$(dirname "$DEVPOD_DIR")}"
: "${DEVPOD_WORKSPACE_FOLDER:=$WORKSPACE_FOLDER}"
: "${AGENTS_DIR:=$WORKSPACE_FOLDER/agents}"

echo "=== Starting TMux Workspace ==="
echo "WORKSPACE_FOLDER: $WORKSPACE_FOLDER"
echo "DEVPOD_WORKSPACE_FOLDER: $DEVPOD_WORKSPACE_FOLDER"
echo "AGENTS_DIR: $AGENTS_DIR"
echo "DEVPOD_DIR: $DEVPOD_DIR"

# Install tmux if not available
if ! command -v tmux >/dev/null 2>&1; then
    echo "📦 Installing tmux and htop..."
    sudo apt-get update -qq
    sudo apt-get install -y tmux htop
    echo "✅ tmux and htop installed successfully"
fi

# Verify tmux installation
if ! command -v tmux >/dev/null 2>&1; then
    echo "❌ tmux installation failed - cannot continue"
    exit 1
fi

# Ensure we're in the workspace directory
cd "$WORKSPACE_FOLDER"

# Kill existing session if it exists and wait for cleanup
if tmux has-session -t workspace 2>/dev/null; then
    echo "🔄 Killing existing tmux session..."
    tmux kill-session -t workspace 2>/dev/null || true
    sleep 0.5  # Give tmux time to clean up
fi

# Create new session with first window for Claude
tmux new-session -d -s workspace -n "Claude-1" -c "$WORKSPACE_FOLDER"

# Set large scrollback buffer for all windows
tmux set-option -g history-limit 50000

# Create additional windows (tmux already created window 0, so start from window 1)
tmux new-window -t workspace -n "Claude-2" -c "$WORKSPACE_FOLDER"
tmux new-window -t workspace -n "Claude-Monitor" -c "$WORKSPACE_FOLDER"
tmux new-window -t workspace -n "htop" -c "$WORKSPACE_FOLDER"

# Get actual window indices (they might not be 0,1,2,3 depending on tmux config)
WINDOWS=($(tmux list-windows -t workspace -F '#{window_index}'))

# Start htop in last window
if command -v htop >/dev/null 2>&1; then
    tmux send-keys -t workspace:${WINDOWS[3]} "htop" C-m 2>/dev/null || true
else
    tmux send-keys -t workspace:${WINDOWS[3]} "echo 'htop not installed. Run: sudo apt-get install -y htop'" C-m 2>/dev/null || true
fi

# Set up Claude Monitor window
if command -v claude-monitor >/dev/null 2>&1; then
    tmux send-keys -t workspace:${WINDOWS[2]} "claude-monitor" C-m 2>/dev/null || true
elif command -v claude-usage-cli >/dev/null 2>&1; then
    tmux send-keys -t workspace:${WINDOWS[2]} "claude-usage-cli" C-m 2>/dev/null || true
else
    tmux send-keys -t workspace:${WINDOWS[2]} "echo 'Claude monitor tools not installed'" C-m 2>/dev/null || true
    tmux send-keys -t workspace:${WINDOWS[2]} "echo 'Run: pip install claude-monitor'" C-m 2>/dev/null || true
fi

# Send helpful messages to Claude windows
tmux send-keys -t workspace:${WINDOWS[0]} "echo '=== Claude Window 1 Ready ==='" C-m 2>/dev/null || true
tmux send-keys -t workspace:${WINDOWS[0]} "echo 'Workspace: $WORKSPACE_FOLDER'" C-m 2>/dev/null || true
tmux send-keys -t workspace:${WINDOWS[0]} "echo 'Agents: $AGENTS_DIR'" C-m 2>/dev/null || true
tmux send-keys -t workspace:${WINDOWS[0]} "echo 'DevPod Dir: $DEVPOD_DIR'" C-m 2>/dev/null || true
tmux send-keys -t workspace:${WINDOWS[0]} "echo ''" C-m 2>/dev/null || true
tmux send-keys -t workspace:${WINDOWS[0]} "echo 'Load mandatory agents with:'" C-m 2>/dev/null || true
tmux send-keys -t workspace:${WINDOWS[0]} "echo 'cat \$AGENTS_DIR/doc-planner.md'" C-m 2>/dev/null || true
tmux send-keys -t workspace:${WINDOWS[0]} "echo 'cat \$AGENTS_DIR/microtask-breakdown.md'" C-m 2>/dev/null || true

tmux send-keys -t workspace:${WINDOWS[1]} "echo '=== Claude Window 2 Ready ==='" C-m 2>/dev/null || true
tmux send-keys -t workspace:${WINDOWS[1]} "echo 'Workspace: $WORKSPACE_FOLDER'" C-m 2>/dev/null || true
tmux send-keys -t workspace:${WINDOWS[1]} "echo 'DevPod Dir: $DEVPOD_DIR'" C-m 2>/dev/null || true

# Select the first window
tmux select-window -t workspace:${WINDOWS[0]} 2>/dev/null || tmux select-window -t workspace:0

echo "✅ TMux workspace 'workspace' created successfully!"
echo "📝 Attaching to tmux session..."

# Attach to the session
tmux attach-session -t workspace
