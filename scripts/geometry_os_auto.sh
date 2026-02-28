#!/bin/bash
#
# Geometry OS Autonomous Loop
#
# Continuously develops Geometry OS toward the goal of running Linux
# or having Linux-equivalent capabilities.
#
# Usage:
#   ./geometry_os_auto.sh              # Start the loop
#   ./geometry_os_auto.sh --dry-run    # Show what would happen
#   touch .geometry/STOP               # Stop the loop
#

set -e

# ============================================================================
# CONFIGURATION
# ============================================================================

TMUX_SESSION="geometry-auto"
WORKER_PANE=0
ORCHESTRATOR_PANE=1
POLL_INTERVAL=5
TURN_END_THRESHOLD=30  # seconds of no activity
DRY_RUN=false

# Paths (relative to script location)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
GEOMETRY_DIR="$PROJECT_ROOT/.geometry"
MANIFEST="$GEOMETRY_DIR/MANIFEST.yaml"
SESSION_STATE="$GEOMETRY_DIR/session_state.json"
MISSION_BRIEFING="$GEOMETRY_DIR/MISSION_BRIEFING.md"
SAFETY_LOG="$GEOMETRY_DIR/safety_log.json"
PLUGINS_REF="$PROJECT_ROOT/docs/designs/PLUGINS.md"
ROADMAP="$PROJECT_ROOT/UNIFIED_ROADMAP_2026.md"
ORCHESTRATOR_PROMPT="$PROJECT_ROOT/docs/designs/ORCHESTRATOR_PROMPT.md"

# Orchestrator fallback chain
ORCHESTRATOR_PRIMARY="gemini"
ORCHESTRATOR_FALLBACK_1="claude --print"
ORCHESTRATOR_FALLBACK_2="lm-studio-complete"

# ============================================================================
# UTILITIES
# ============================================================================

log() {
  local level="$1"
  shift
  local msg="$*"
  local timestamp=$(date -Iseconds)
  echo "[$timestamp] [$level] $msg" | tee -a "$GEOMETRY_DIR/loop.log"
}

info() { log "INFO" "$@"; }
warn() { log "WARN" "$@"; }
error() { log "ERROR" "$@"; }

yaml_read() {
  local file="$1"
  local path="$2"
  local default="${3:-}"

  if [ ! -f "$file" ]; then
    echo "$default"
    return
  fi

  # Use python for YAML reading (more reliable than yq)
  python3 -c "
import yaml
import sys
try:
    with open('$file', 'r') as f:
        data = yaml.safe_load(f)
    value = data
    for key in '$path'.replace('.', '][').strip('[]').split(']['):
        if key.isdigit():
            value = value[int(key)]
        else:
            value = value.get(key, None)
        if value is None:
            break
    if value is None:
        print('$default')
    else:
        print(value)
except Exception as e:
    print('$default')
" 2>/dev/null || echo "$default"
}

yaml_write() {
  local file="$1"
  local path="$2"
  local value="$3"

  python3 -c "
import yaml
import json

with open('$file', 'r') as f:
    data = yaml.safe_load(f) or {}

# Navigate to the path and set value
keys = '$path'.split('.')
obj = data
for key in keys[:-1]:
    if key.isdigit():
        key = int(key)
    if key not in obj:
        obj[key] = {}
    obj = obj[key]

last_key = keys[-1]
# Try to parse as JSON, otherwise use as string
try:
    obj[last_key] = json.loads('''$value''')
except:
    obj[last_key] = '''$value'''

with open('$file', 'w') as f:
    yaml.dump(data, f, default_flow_style=False)
"
}

json_append() {
  local file="$1"
  local event_json="$2"

  python3 -c "
import json

try:
    with open('$file', 'r') as f:
        data = json.load(f)
except:
    data = {'events': []}

event = json.loads('''$event_json''')
data['events'].append(event)

# Keep only last 1000 events
data['events'] = data['events'][-1000:]

with open('$file', 'w') as f:
    json.dump(data, f, indent=2)
"
}

# ============================================================================
# INITIALIZATION
# ============================================================================

init_directories() {
  mkdir -p "$GEOMETRY_DIR"
  mkdir -p "$(dirname "$PLUGINS_REF")"
}

init_manifest() {
  if [ ! -f "$MANIFEST" ]; then
    info "Creating initial MANIFEST.yaml"
    cat > "$MANIFEST" << 'EOF'
meta:
  goal: "Geometry OS runs Linux or has Linux-equivalent capabilities"
  created: PLACEHOLDER
  last_updated: PLACEHOLDER
  version: 1

phase:
  current: "A"
  name: "Foundation"
  status: "pending"
  completion_pct: 0

task:
  current: null
  description: null
  status: "pending"

completion_promises: []

dirty_bits:
  code_modified: false
  tests_run: false
  tests_passing: null
  docs_updated: false

safety:
  iteration_count: 0
  max_iterations: 100
  consecutive_failures: 0
  max_consecutive_failures: 3
  last_tool_signatures: []
  signature_history_depth: 10
  soft_loop_threshold: 3
  hard_loop_threshold: 5
  loop_detected: false

context:
  estimated_usage_pct: 0
  compaction_threshold: 85
  last_compaction: null
EOF
    # Replace placeholders with actual timestamps
    sed -i "s/PLACEHOLDER/$(date -Iseconds)/g" "$MANIFEST"
  fi
}

init_session_state() {
  if [ ! -f "$SESSION_STATE" ]; then
    cat > "$SESSION_STATE" << EOF
{
  "session_id": "auto-$(date +%Y-%m-%d-%H%M%S)",
  "started": "$(date -Iseconds)",
  "turn_count": 0,
  "recent_actions": [],
  "tool_signature_buffer": [],
  "failure_count": 0,
  "last_orchestrator_prompt": null,
  "worker_output_buffer": ""
}
EOF
  fi
}

init_safety_log() {
  if [ ! -f "$SAFETY_LOG" ]; then
    echo '{"events": []}' > "$SAFETY_LOG"
  fi
}

init_tmux() {
  if ! tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
    info "Creating tmux session: $TMUX_SESSION"

    if [ "$DRY_RUN" = true ]; then
      info "[DRY-RUN] Would create tmux session with 2 panes"
      return
    fi

    tmux new-session -d -s "$TMUX_SESSION" -x 200 -y 50 -c "$PROJECT_ROOT"
    tmux split-window -h -t "$TMUX_SESSION" -c "$PROJECT_ROOT"

    # Pane 0: Worker (Claude Code)
    tmux send-keys -t "$TMUX_SESSION:$WORKER_PANE" "# Worker pane - Claude Code will run here" Enter
    tmux send-keys -t "$TMUX_SESSION:$WORKER_PANE" "cd $PROJECT_ROOT" Enter

    # Pane 1: Orchestrator (idle until triggered)
    tmux send-keys -t "$TMUX_SESSION:$ORCHESTRATOR_PANE" "# Orchestrator pane" Enter
    tmux send-keys -t "$TMUX_SESSION:$ORCHESTRATOR_PANE" "cd $PROJECT_ROOT" Enter

    info "Tmux session created. Attach with: tmux attach -t $TMUX_SESSION"
  fi
}

# ============================================================================
# CAPTURE
# ============================================================================

capture_worker_output() {
  if [ "$DRY_RUN" = true ]; then
    echo "[DRY-RUN] Simulated worker output"
    return
  fi

  tmux capture-pane -t "$TMUX_SESSION:$WORKER_PANE" -p -S -500 2>/dev/null || echo ""
}

estimate_context_usage() {
  local output="$1"
  local line_count=$(echo "$output" | wc -l)
  # Rough heuristic: 500 lines ≈ 70% context
  echo $((line_count * 70 / 500))
}

extract_tool_signatures() {
  local output="$1"
  # Extract patterns like "Edit(file=...)" or "Bash(cmd=...)"
  echo "$output" | grep -oE '(Edit|Bash|Read|Write|Grep|Glob|Agent)\([^)]+\)' 2>/dev/null | tail -10 || echo ""
}

get_last_activity_time() {
  local state_file="$1"

  python3 -c "
import json
try:
    with open('$state_file', 'r') as f:
        data = json.load(f)
    print(data.get('last_activity', 0))
except:
    print(0)
"
}

# ============================================================================
# DETECTION
# ============================================================================

is_turn_end() {
  local output="$1"
  local last_activity="$2"
  local now=$(date +%s)

  # Check for explicit completion markers
  if echo "$output" | tail -30 | grep -qE "(TASK_COMPLETE|Done|Finished|Complete|✓|All tests passed)"; then
    return 0
  fi

  # Check for Claude Code prompt (waiting for input)
  if echo "$output" | tail -5 | grep -qE "❯|>$"; then
    return 0
  fi

  # Check for inactivity
  local elapsed=$((now - last_activity))
  if [ "$elapsed" -gt "$TURN_END_THRESHOLD" ]; then
    return 0
  fi

  return 1
}

is_looping() {
  local signatures="$1"
  local threshold="${2:-3}"

  if [ -z "$signatures" ]; then
    return 1
  fi

  # Check for N+ identical consecutive signatures
  local sig_array=($signatures)
  local last_sig=""
  local count=0

  for sig in "${sig_array[@]}"; do
    if [ "$sig" == "$last_sig" ]; then
      ((count++))
      if [ "$count" -ge "$threshold" ]; then
        return 0
      fi
    else
      count=1
      last_sig="$sig"
    fi
  done

  return 1
}

check_compaction_gate() {
  local context_pct="$1"
  local threshold=$(yaml_read "$MANIFEST" "context.compaction_threshold" 85)

  if [ "$context_pct" -gt "$threshold" ]; then
    return 0  # Needs compaction
  fi
  return 1
}

check_dirty_bits() {
  local code_modified=$(yaml_read "$MANIFEST" "dirty_bits.code_modified" false)
  local tests_run=$(yaml_read "$MANIFEST" "dirty_bits.tests_run" false)

  if [ "$code_modified" = "true" ] && [ "$tests_run" = "false" ]; then
    return 0  # Dirty: must run tests
  fi
  return 1
}

check_iteration_cap() {
  local count=$(yaml_read "$MANIFEST" "safety.iteration_count" 0)
  local max=$(yaml_read "$MANIFEST" "safety.max_iterations" 100)

  if [ "$count" -ge "$max" ]; then
    return 0  # Cap reached
  fi
  return 1
}

check_failure_cap() {
  local count=$(yaml_read "$MANIFEST" "safety.consecutive_failures" 0)
  local max=$(yaml_read "$MANIFEST" "safety.max_consecutive_failures" 3)

  if [ "$count" -ge "$max" ]; then
    return 0  # Too many failures
  fi
  return 1
}

# ============================================================================
# JUDGMENT
# ============================================================================

generate_mission_briefing() {
  local worker_output="$1"
  local context_pct="$2"

  # Read current state
  local current_phase=$(yaml_read "$MANIFEST" "phase.current" "A")
  local phase_name=$(yaml_read "$MANIFEST" "phase.name" "Unknown")
  local phase_status=$(yaml_read "$MANIFEST" "phase.status" "pending")
  local current_task=$(yaml_read "$MANIFEST" "task.current" "null")
  local task_desc=$(yaml_read "$MANIFEST" "task.description" "")
  local iteration=$(yaml_read "$MANIFEST" "safety.iteration_count" 0)
  local failures=$(yaml_read "$MANIFEST" "safety.consecutive_failures" 0)
  local loop_detected=$(yaml_read "$MANIFEST" "safety.loop_detected" false)

  local code_mod=$(yaml_read "$MANIFEST" "dirty_bits.code_modified" false)
  local tests_run=$(yaml_read "$MANIFEST" "dirty_bits.tests_run" false)
  local tests_pass=$(yaml_read "$MANIFEST" "dirty_bits.tests_passing" "null")

  cat > "$MISSION_BRIEFING" << EOF
# Mission Briefing - $(date -Iseconds)

## Goal
Geometry OS runs Linux or has Linux-equivalent capabilities

## Current State
- **Phase**: $current_phase ($phase_name)
- **Status**: $phase_status
- **Task**: ${current_task:-none} - ${task_desc:-no task}
- **Context Usage**: ${context_pct}%

## Recent Worker Output (last 50 lines)
\`\`\`
$(echo "$worker_output" | tail -50)
\`\`\`

## Dirty Bits Status
| Check | Status | Action Required |
|-------|--------|-----------------|
| Code modified | $code_mod | $( [ "$code_mod" = "true" ] && echo "Tests must be run" || echo "-" ) |
| Tests run | $tests_run | $( [ "$tests_run" = "false" ] && [ "$code_mod" = "true" ] && echo "⚠️ REQUIRED" || echo "-" ) |
| Tests passing | $tests_pass | - |

## Safety Status
- Iterations: $iteration/100
- Consecutive failures: $failures/3
- Loop detected: $loop_detected

## Recommended Next Step
$( if [ "$code_mod" = "true" ] && [ "$tests_run" = "false" ]; then
    echo "Run tests: pytest tests/"
  elif [ "$failures" -ge 2 ]; then
    echo "/superpowers:systematic-debugging"
  elif [ "$loop_detected" = "true" ]; then
    echo "Try a different approach: /ralph-specum:research"
  elif [ "$phase_status" = "complete" ]; then
    echo "/gsd:progress"
  else
    echo "Continue with current task or /gsd:progress"
  fi )

## Available Plugins Reference
See: $PLUGINS_REF
EOF

  info "Generated Mission Briefing"
}

run_orchestrator() {
  local mission_briefing_file="$1"
  local next_prompt=""

  # Read the short orchestrator prompt
  local orch_prompt="
You are the Orchestrator. Judge the worker session and output ONLY the next prompt.

GOAL: Geometry OS runs Linux or has Linux-equivalent capabilities.

Read this Mission Briefing:

$(cat "$mission_briefing_file")

PRIORITY ORDER:
1. If code modified but tests not run → Output: Run tests: pytest tests/
2. If stuck/failing → Output: /superpowers:systematic-debugging
3. If making progress → Output: Continue with current task
4. If phase complete → Output: /gsd:progress
5. If unsure → Output: /gsd:progress

OUTPUT: One prompt only. No explanations. No markdown. Just the prompt text.
"

  # Try primary orchestrator (Gemini)
  if command -v gemini &> /dev/null; then
    info "Trying orchestrator: gemini"
    next_prompt=$(echo "$orch_prompt" | gemini 2>/dev/null | head -1) || true
  fi

  # Fallback 1: Claude Code
  if [ -z "$next_prompt" ] && command -v claude &> /dev/null; then
    info "Fallback to: claude --print"
    next_prompt=$(echo "$orch_prompt" | claude --print 2>/dev/null | head -1) || true
  fi

  # Fallback 2: LM Studio (if available)
  if [ -z "$next_prompt" ]; then
    info "Fallback to: heuristic selection"
    # Use simple heuristics as final fallback
    local code_mod=$(yaml_read "$MANIFEST" "dirty_bits.code_modified" false)
    local tests_run=$(yaml_read "$MANIFEST" "dirty_bits.tests_run" false)
    local failures=$(yaml_read "$MANIFEST" "safety.consecutive_failures" 0)

    if [ "$code_mod" = "true" ] && [ "$tests_run" = "false" ]; then
      next_prompt="Run tests to verify your changes: pytest tests/"
    elif [ "$failures" -ge 2 ]; then
      next_prompt="/superpowers:systematic-debugging"
    else
      next_prompt="/gsd:progress"
    fi
  fi

  # Clean up the prompt
  next_prompt=$(echo "$next_prompt" | sed 's/^```.*$//' | sed 's/```$//' | tr -d '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

  echo "$next_prompt"
}

invoke_out_of_band_advisor() {
  warn "Invoking out-of-band advisor for cognitive deadlock..."

  local transcript=$(capture_worker_output)

  local advice_prompt="You are an Out-of-Band Advisor. The autonomous loop is stuck.

TRANSCRIPT (recent output):
$transcript

Analyze the cognitive deadlock and provide:
1. Root cause of the stuck state
2. A completely different approach to try
3. The exact prompt to inject

Output the prompt to inject, nothing else."

  local advice=""

  # Try Claude Opus first (highest reasoning)
  if command -v claude &> /dev/null; then
    advice=$(echo "$advice_prompt" | claude --model claude-opus-4-6 --print 2>/dev/null | head -1) || true
  fi

  # Fallback to gemini
  if [ -z "$advice" ] && command -v gemini &> /dev/null; then
    advice=$(echo "$advice_prompt" | gemini 2>/dev/null | head -1) || true
  fi

  if [ -z "$advice" ]; then
    advice="Stop the current approach. Take a step back and research alternative methods with /ralph-specum:research"
  fi

  # Log this event
  json_append "$SAFETY_LOG" "{\"timestamp\": \"$(date -Iseconds)\", \"type\": \"OUT_OF_BAND_ADVISOR\", \"details\": {\"advice\": \"$advice\"}, \"action_taken\": \"injected_advice\"}"

  echo "$advice"
}

create_checkpoint() {
  local reason="$1"

  cat > "$GEOMETRY_DIR/CHECKPOINT.md" << EOF
# Checkpoint - $(date -Iseconds)

## Reason
$reason

## Current State
- Phase: $(yaml_read "$MANIFEST" "phase.current" "?")
- Task: $(yaml_read "$MANIFEST" "task.current" "?")
- Iterations: $(yaml_read "$MANIFEST" "safety.iteration_count" 0)

## To Continue
Delete this file to resume: rm .geometry/CHECKPOINT.md

Or run: /gsd:resume-work
EOF

  warn "Checkpoint created: $GEOMETRY_DIR/CHECKPOINT.md"
}

create_blocker_report() {
  local reason="$1"

  cat > "$GEOMETRY_DIR/BLOCKER_REPORT.md" << EOF
# Blocker Report - $(date -Iseconds)

## Issue
$reason

## Current State
- Phase: $(yaml_read "$MANIFEST" "phase.current" "?")
- Task: $(yaml_read "$MANIFEST" "task.current" "?")
- Consecutive failures: $(yaml_read "$MANIFEST" "safety.consecutive_failures" 0)

## Recent Worker Output
\`\`\`
$(capture_worker_output | tail -100)
\`\`\`

## Suggested Actions
1. Review the worker output above
2. Fix the underlying issue manually
3. Delete this file to resume: rm .geometry/BLOCKER_REPORT.md
EOF

  error "Blocker report created: $GEOMETRY_DIR/BLOCKER_REPORT.md"
}

# ============================================================================
# INJECTION
# ============================================================================

inject_prompt() {
  local prompt="$1"

  info "Injecting prompt: $prompt"

  if [ "$DRY_RUN" = true ]; then
    info "[DRY-RUN] Would send to worker: $prompt"
    return
  fi

  # Update session state with last prompt
  python3 -c "
import json
with open('$SESSION_STATE', 'r') as f:
    data = json.load(f)
data['last_orchestrator_prompt'] = '''$prompt'''
data['turn_count'] = data.get('turn_count', 0) + 1
with open('$SESSION_STATE', 'w') as f:
    json.dump(data, f, indent=2)
"

  tmux send-keys -t "$TMUX_SESSION:$WORKER_PANE" "$prompt" Enter
}

start_worker() {
  info "Starting Claude Code worker..."

  if [ "$DRY_RUN" = true ]; then
    info "[DRY-RUN] Would start claude in worker pane"
    return
  fi

  tmux send-keys -t "$TMUX_SESSION:$WORKER_PANE" "claude" Enter
  sleep 3

  # Inject initial context
  local initial_prompt="Read .geometry/MISSION_BRIEFING.md if it exists, then check /gsd:progress to see what to work on next."
  inject_prompt "$initial_prompt"
}

restart_worker() {
  info "Restarting worker for context compaction..."

  if [ "$DRY_RUN" = true ]; then
    info "[DRY-RUN] Would restart worker"
    return
  fi

  # Send Ctrl+C to stop current session
  tmux send-keys -t "$TMUX_SESSION:$WORKER_PANE" C-c
  sleep 2

  # Start fresh
  tmux send-keys -t "$TMUX_SESSION:$WORKER_PANE" "claude" Enter
  sleep 3

  # Inject briefing prompt
  inject_prompt "Read .geometry/MISSION_BRIEFING.md and continue from where we left off."
}

# ============================================================================
# STATE UPDATES
# ============================================================================

update_manifest() {
  # Update last_updated timestamp
  yaml_write "$MANIFEST" "meta.last_updated" "\"$(date -Iseconds)\""
}

increment_iteration() {
  local current=$(yaml_read "$MANIFEST" "safety.iteration_count" 0)
  local new_count=$((current + 1))
  yaml_write "$MANIFEST" "safety.iteration_count" "$new_count"
  info "Iteration: $new_count"
}

record_tool_signature() {
  local sig="$1"

  python3 -c "
import yaml
import json

with open('$MANIFEST', 'r') as f:
    data = yaml.safe_load(f)

sigs = data.get('safety', {}).get('last_tool_signatures', [])
sigs.append('$sig')
# Keep only last 10
sigs = sigs[-10:]
data['safety']['last_tool_signatures'] = sigs

with open('$MANIFEST', 'w') as f:
    yaml.dump(data, f)
"
}

# ============================================================================
# MAIN LOOP
# ============================================================================

check_stop_signal() {
  [ -f "$GEOMETRY_DIR/STOP" ]
}

check_pause_signal() {
  [ -f "$GEOMETRY_DIR/PAUSE" ]
}

check_checkpoint_exists() {
  [ -f "$GEOMETRY_DIR/CHECKPOINT.md" ]
}

check_blocker_exists() {
  [ -f "$GEOMETRY_DIR/BLOCKER_REPORT.md" ]
}

main() {
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      *)
        shift
        ;;
    esac
  done

  info "=========================================="
  info "Geometry OS Autonomous Loop"
  info "=========================================="
  info "Goal: Geometry OS runs Linux or has Linux-equivalent capabilities"
  info "Dry run: $DRY_RUN"
  info ""

  # Initialize
  init_directories
  init_manifest
  init_session_state
  init_safety_log
  init_tmux

  # Start worker if not in dry run
  if [ "$DRY_RUN" = false ]; then
    start_worker
  fi

  local last_activity=$(date +%s)
  local last_output=""
  local loop_count=0

  info "Entering main loop..."

  while true; do
    loop_count=$((loop_count + 1))

    # Check for stop/pause signals
    if check_stop_signal; then
      info "Stop signal received"
      rm -f "$GEOMETRY_DIR/STOP"
      break
    fi

    if check_pause_signal; then
      info "Pause signal received, waiting..."
      sleep 10
      continue
    fi

    if check_checkpoint_exists; then
      info "Checkpoint exists, waiting for manual resume..."
      sleep 10
      continue
    fi

    if check_blocker_exists; then
      info "Blocker exists, waiting for manual resolution..."
      sleep 10
      continue
    fi

    # 1. CAPTURE
    local worker_output=$(capture_worker_output)
    local context_pct=$(estimate_context_usage "$worker_output")
    local tool_sigs=$(extract_tool_signatures "$worker_output")

    # Update context estimate in manifest
    yaml_write "$MANIFEST" "context.estimated_usage_pct" "$context_pct"

    # Detect if output changed (activity)
    if [ "$worker_output" != "$last_output" ]; then
      last_activity=$(date +%s)
      last_output="$worker_output"

      # Record tool signatures
      if [ -n "$tool_sigs" ]; then
        for sig in $tool_sigs; do
          record_tool_signature "$sig"
        done
      fi
    fi

    # 2. DETECT TURN END
    if is_turn_end "$worker_output" "$last_activity"; then
      info "Turn ended, starting judgment phase..."

      # 2a. ITERATION CAP
      if check_iteration_cap; then
        create_checkpoint "Reached iteration cap: $(yaml_read "$MANIFEST" 'safety.iteration_count' 0)/$(yaml_read "$MANIFEST" 'safety.max_iterations' 100)"
        break
      fi

      # 2b. FAILURE CAP
      if check_failure_cap; then
        create_blocker_report "Too many consecutive failures: $(yaml_read "$MANIFEST" 'safety.consecutive_failures' 0)"
        break
      fi

      # 2c. COMPACTION GATE
      if check_compaction_gate "$context_pct"; then
        info "Context at ${context_pct}%, triggering compaction"
        generate_mission_briefing "$worker_output" "$context_pct"
        json_append "$SAFETY_LOG" "{\"timestamp\": \"$(date -Iseconds)\", \"type\": \"COMPACTION_GATE\", \"details\": {\"context_pct\": $context_pct}, \"action_taken\": \"restarted_session\"}"
        restart_worker
        last_activity=$(date +%s)
        continue
      fi

      # 2d. LOOP DETECTION
      local hard_threshold=$(yaml_read "$MANIFEST" "safety.hard_loop_threshold" 5)
      if is_looping "$tool_sigs" "$hard_threshold"; then
        warn "Hard loop detected!"
        yaml_write "$MANIFEST" "safety.loop_detected" "true"
        json_append "$SAFETY_LOG" "{\"timestamp\": \"$(date -Iseconds)\", \"type\": \"HARD_LOOP\", \"details\": {\"signatures\": \"$tool_sigs\"}, \"action_taken\": \"out_of_band_advisor\"}"
        local advice=$(invoke_out_of_band_advisor)
        inject_prompt "$advice"
        last_activity=$(date +%s)
        continue
      fi

      # Soft loop warning
      local soft_threshold=$(yaml_read "$MANIFEST" "safety.soft_loop_threshold" 3)
      if is_looping "$tool_sigs" "$soft_threshold"; then
        warn "Soft loop detected (monitoring)"
        json_append "$SAFETY_LOG" "{\"timestamp\": \"$(date -Iseconds)\", \"type\": \"SOFT_LOOP\", \"details\": {\"signatures\": \"$tool_sigs\"}, \"action_taken\": \"continued_monitoring\"}"
      fi

      # 2e. DIRTY BIT CHECK
      if check_dirty_bits; then
        info "Dirty bits: code modified but tests not run"
        json_append "$SAFETY_LOG" "{\"timestamp\": \"$(date -Iseconds)\", \"type\": \"DIRTY_BIT_VIOLATION\", \"details\": {\"code_modified\": true, \"tests_run\": false}, \"action_taken\": \"injected_test_prompt\"}"
        inject_prompt "You modified code but haven't run tests. Run tests now: pytest tests/"
        last_activity=$(date +%s)
        continue
      fi

      # 3. JUDGMENT
      generate_mission_briefing "$worker_output" "$context_pct"
      local next_prompt=$(run_orchestrator "$MISSION_BRIEFING")

      # 4. INJECT
      if [ -n "$next_prompt" ]; then
        inject_prompt "$next_prompt"

        # 5. UPDATE STATE
        increment_iteration
        update_manifest
      else
        warn "No prompt generated, using fallback"
        inject_prompt "/gsd:progress"
      fi

      # Reset activity timer
      last_activity=$(date +%s)
    fi

    # Sleep before next check
    sleep "$POLL_INTERVAL"
  done

  info "Autonomous loop ended after $loop_count checks"
  info "To resume: rm .geometry/STOP .geometry/CHECKPOINT.md .geometry/BLOCKER_REPORT.md 2>/dev/null; ./scripts/geometry_os_auto.sh"
}

# Run
main "$@"
