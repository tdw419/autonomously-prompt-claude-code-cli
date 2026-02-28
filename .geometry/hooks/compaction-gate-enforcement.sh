#!/bin/bash
#
# Compaction Gate Enforcement Hook
#
# This hook enforces context window limits to prevent "hallucinated success"
# that occurs when a model loses access to earlier instructions.
#
# Usage: Run this as a PostToolUse hook or periodically via cron
#

set -e

# Configuration
GEOMETRY_DIR="${GEOMETRY_DIR:-.geometry}"
MANIFEST="$GEOMETRY_DIR/MANIFEST.yaml"
LOG_FILE="$GEOMETRY_DIR/loop.log"

# Thresholds (for 200K token window)
WARNING_THRESHOLD=75     # 150K tokens
MANDATORY_THRESHOLD=80   # 160K tokens
HARD_BLOCK_THRESHOLD=85  # 170K tokens

# Logging
log() {
    echo "[$(date -Iseconds)] [COMPACTION] $1" | tee -a "$LOG_FILE"
}

# Estimate context usage from terminal output
estimate_context() {
    local lines=0

    # Try to get from tmux if available
    if command -v tmux &> /dev/null && tmux has-session -t geometry-auto 2>/dev/null; then
        lines=$(tmux capture-pane -t geometry-auto:0 -p 2>/dev/null | wc -l) || lines=0
    fi

    # Rough heuristic: 500 lines ≈ 70% context
    if [ "$lines" -gt 0 ]; then
        echo $((lines * 70 / 500))
    else
        # Fallback: read from session state
        if [ -f "$GEOMETRY_DIR/session_state.json" ]; then
            python3 -c "
import json
try:
    with open('$GEOMETRY_DIR/session_state.json', 'r') as f:
        data = json.load(f)
    buffer = data.get('worker_output_buffer', '')
    lines = len(buffer.split('\n')) if buffer else 0
    print(min(100, int(lines * 70 / 500)) if lines > 0 else 0)
except:
    print(0)
" 2>/dev/null || echo 0
        else
            echo 0
        fi
    fi
}

# Generate mission briefing for handoff
generate_briefing() {
    local context_pct="$1"

    if [ -f "$GEOMETRY_DIR/../scripts/geometry_os_auto.sh" ]; then
        # Source the script's function if possible
        log "Generating mission briefing for compaction handoff..."
        # The main script handles this
    fi

    # Create compaction marker
    echo "$(date -Iseconds)" > "$GEOMETRY_DIR/.compaction_pending"
    log "Compaction marker created. Worker will restart with fresh context."
}

# Main logic
main() {
    local context_pct=$(estimate_context)

    # Update manifest with current context
    if [ -f "$MANIFEST" ] && command -v python3 &> /dev/null; then
        python3 -c "
import yaml
try:
    with open('$MANIFEST', 'r') as f:
        data = yaml.safe_load(f)
    if 'context' not in data:
        data['context'] = {}
    data['context']['estimated_usage_pct'] = $context_pct
    with open('$MANIFEST', 'w') as f:
        yaml.dump(data, f)
except:
    pass
" 2>/dev/null || true
    fi

    # Check thresholds
    if [ "$context_pct" -ge "$HARD_BLOCK_THRESHOLD" ]; then
        log "HARD_BLOCK: Context at ${context_pct}%"
        log "Action required: Run /compact or restart session manually"
        echo ""
        echo "╔══════════════════════════════════════════════════════════════╗"
        echo "║  HARD BLOCK: Context window at ${context_pct}%                          ║"
        echo "║                                                              ║"
        echo "║  Further tool calls are blocked to prevent reasoning decay. ║"
        echo "║                                                              ║"
        echo "║  Action required:                                           ║"
        echo "║    1. Run /compact to summarize session                     ║"
        echo "║    2. Or restart with: rm .geometry/.compaction_pending     ║"
        echo "║       && ./scripts/geometry_os_auto.sh                       ║"
        echo "╚══════════════════════════════════════════════════════════════╝"
        echo ""
        exit 1

    elif [ "$context_pct" -ge "$MANDATORY_THRESHOLD" ]; then
        log "MANDATORY: Context at ${context_pct}%, triggering compaction"
        generate_briefing "$context_pct"
        echo ""
        echo "⚠️  MANDATORY COMPACTION: Context at ${context_pct}%"
        echo "    Mission briefing generated. Session will restart."
        echo ""

    elif [ "$context_pct" -ge "$WARNING_THRESHOLD" ]; then
        log "WARNING: Context at ${context_pct}%"
        echo ""
        echo "⚠️  WARNING: Context at ${context_pct}%"
        echo "    Consider running /compact to free up context."
        echo ""
    fi

    exit 0
}

# Run
main "$@"
