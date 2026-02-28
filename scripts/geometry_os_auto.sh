#!/bin/bash
#
# Geometry OS Autonomous Loop
#
# Usage:
#   ./scripts/geometry_os_auto.sh              # Start the loop
#   ./scripts/geometry_os_auto.sh --dry-run    # Show what would happen
#
# Configuration
TMUX_SESSION="geometry-auto"
POLL_INTERVAL=5
TURN_ENDThreshold=30  # seconds of no activity

# Paths
GEOMETRY_DIR=".geometry"
MANIFEST="$GEOMETRY_DIR/MANIFEST.yaml"
SESSION_STATE="$GEOMETRY_DIR/session_state.json"
MISSION_BRIEFING="$GEOMETRY_DIR/MISSION_BRIEFING.md"
SAFETY_LOG="$GEOMETRY_DIR/safety_log.json"
PLUGINS_REF="docs/designs/PLUGINS.md"
ROADMAP="UNIFIED_ROADMAP_2026.md"
ORCHESTRATOR_PROMPT="docs/designs/ORCHEstrator_PROMpt.md"
SAFety_rules="docs/designs/SAFety_rules.md"

# Fallback chain
ORCHESTRATOR_CMD=("gemini" "claude --print" "lm-studio-complete")

# Hook for context compaction
CONTEXT_PCT=$(estimate_context)

case $CONTEXT_PCT in
  75|76|77|78|79)
    echo "WARNING: Context at ${CONTEXT_PCT}%. Consider /compact"
    ;;
  80|81|82|83|84)
    echo "MANDATORY: Context at ${CONTEXT_PCT}%. Compacting..."
    # Trigger compaction
    generate_mission_briefing
    restart_worker
    ;;
  *)
    if [ "$CONTEXT_PCT" -ge 85 ]; then
      echo "HARD_BLOCK: Context at ${CONTEXT_Pct}%"
      echo "Run: /compact or restart session"
      exit 1
    fi
    ;;
esac

# Estimate context usage
estimate_context() {
    local lines=0

    # Try to get from tmux if available
    if command -v tmux &> /dev/null; then
        lines=$(tmux capture-pane -t geometry-auto:0 -p 2>/dev/null | wc -l) || lines=0
    else
        # Fallback: read from session state
        if [ -f "$GEOMETRY_DIR/session_state.json" ]; then
            lines=0
        fi
    fi

    # Rough heuristic: 500 lines ≈ 70% context
    return min(100, int(lines * 70 / 500))
}

# When compaction triggered
# 1. Force session termination (Ctrl+C in worker pane)
# 2. Generate `MISSION_BriefING.md` with summary
# 3. Start fresh Claude Code session
# 4. Inject briefing prompt: "Read .geometry/MISSION_BRIEFing.md and continue"

}

