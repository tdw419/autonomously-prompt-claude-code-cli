# Geometry OS Autonomous Loop - Quick Start

## What This Does

Continuously develops Geometry OS toward the goal of running Linux or having Linux-equivalent capabilities. Uses a two-agent architecture:

- **Worker** (Claude Code) - Executes tasks
- **Orchestrator** (Gemini CLI / Fallbacks) - Judges progress and decides next steps

## Start the Loop

```bash
cd /home/jericho/zion/projects/geometry_os/geometry_os
./scripts/geometry_os_auto.sh
```

## Monitor Progress

```bash
# Attach to tmux session (Ctrl+B D to detach)
tmux attach -t geometry-auto

# Watch logs
tail -f .geometry/loop.log

# Check current state
cat .geometry/MANIFEST.yaml
cat .geometry/MISSION_BRIEFING.md
```

## Stop the Loop

```bash
# Signal stop
touch .geometry/STOP

# Or from inside tmux: Ctrl+C in orchestrator pane
```

## Pause/Resume

```bash
# Pause
touch .geometry/PAUSE

# Resume
rm .geometry/PAUSE
```

## Reset After Blocker

```bash
# Clear blocker and continue
rm .geometry/BLOCKER_REPORT.md
rm .geometry/CHECKPOINT.md

# Or reset failure counter
# Edit .geometry/MANIFEST.yaml:
# safety.consecutive_failures: 0
```

## Files

| File | Purpose |
|------|---------|
| `.geometry/MANIFEST.yaml` | Source of truth for progress |
| `.geometry/session_state.json` | Runtime session state |
| `.geometry/MISSION_BRIEFING.md` | Generated handoff document |
| `.geometry/loop.log` | Execution log |
| `.geometry/safety_log.json` | Safety event log |

## Configuration

Edit `.geometry/MANIFEST.yaml` to adjust:

- `safety.max_iterations` - Iteration cap (default: 100)
- `safety.max_consecutive_failures` - Failure tolerance (default: 3)
- `context.compaction_threshold` - Context % for restart (default: 85)

## Troubleshooting

### Loop keeps stopping
Check `.geometry/BLOCKER_REPORT.md` for the issue.

### Context too large
The system auto-compacts at 85% context. Lower `compaction_threshold` if needed.

### Orchestrator not working
Ensure `gemini` CLI is installed, or the fallbacks (`claude`, `lm-studio-complete`) are available.

## Design Docs

- [Full Design Document](AUTONOMOUS_LOOP_DESIGN.md)
- [Plugin Reference](PLUGINS.md)
- [Safety Rules](SAFETY_RULES.md)
- [Orchestrator Prompt](ORCHESTRATOR_PROMPT.md)
