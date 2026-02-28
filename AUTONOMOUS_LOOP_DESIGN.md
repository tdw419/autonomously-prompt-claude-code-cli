# Geometry OS Autonomous Loop - Design Document

> **Goal**: Continuously develop Geometry OS until it can run Linux or has Linux-equivalent capabilities.

## Executive Summary

This document describes a two-agent cognitive architecture that enables autonomous, continuous development of Geometry OS. The system uses an **Orchestrator-Worker** pattern where:

1. **Worker** (Claude Code) - Executes tasks, writes code, runs tests
2. **Orchestrator** (Gemini CLI / Fallbacks) - Judges progress, determines next steps, generates prompts

The system operates through intelligent session handoff, analyzing context and roadmap state to determine optimal next actions without human intervention.

**Key Principles**:
- **Thin Agent Pattern**: Workers are stateless with minimal instructions (<150 lines)
- **Context Hygiene**: Maximum context reserved for task-specific code
- **Isolation of Responsibilities**: Strict separation between planning, execution, and verification
- **Cryptographic Identity**: Agent configurations are checksummed for audit trails

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                    GEOMETRY OS AUTONOMOUS LOOP                       │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │                        TMUX SESSION                             │ │
│  ├────────────────────────────────┬───────────────────────────────┤ │
│  │  PANE 0: WORKER                │  PANE 1: ORCHESTRATOR         │ │
│  │  (Claude Code)                 │  (Gemini CLI / Fallbacks)     │ │
│  │                                │                               │ │
│  │  - Executes tasks              │  - Judgment phase             │ │
│  │  - Writes code                 │  - Generates Mission Briefing │ │
│  │  - Runs tests                  │  - Detects loops/blockers     │ │
│  │  - Reports completion          │  - Outputs next prompt        │ │
│  └────────────────────────────────┴───────────────────────────────┘ │
│                                                                      │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │                     STATE LAYER                                 │ │
│  ├──────────────────┬──────────────────┬──────────────────────────┤ │
│  │ MANIFEST.yaml    │ session_state.json│ MISSION_BRIEFING.md     │ │
│  │ - Phase tracking │ - Recent actions  │ - Current goal           │ │
│  │ - Completion     │ - Tool signatures │ - Blockers encountered   │ │
│  │   promises       │ - Failure count   │ - Recommended next step  │ │
│  │ - Dirty bits     │ - Context %       │ - Plugin to use          │ │
│  └──────────────────┴──────────────────┴──────────────────────────┘ │
│                                                                      │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │                     REFERENCE LAYER                             │ │
│  ├──────────────────┬──────────────────┬──────────────────────────┤ │
│  │ PLUGINS.md       │ ROADMAP.md       │ SAFETY_RULES.md          │ │
│  │ - /superpowers   │ - Phases A-U     │ - Loop detection rules   │ │
│  │ - /ralph-specum  │ - Task status    │ - Dirty bit checks       │ │
│  │ - /gsd           │ - Dependencies   │ - Iteration caps         │ │
│  │ - /bmad          │                  │ - Circuit breaker        │ │
│  └──────────────────┴──────────────────┴──────────────────────────┘ │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Permission Modalities and Automated Velocity

Claude Code provides distinct permission modes that govern the balance between human oversight and agentic autonomy. For Geometry OS, selection is dictated by task criticality and scope.

| Permission Mode | CLI Flag | Authorization Scope | Use Case |
|:---------------|:---------|:--------------------|:---------|
| Default | (None) | Confirmation required for all edits and commands | Strategic human-led architectural reviews |
| acceptEdits | `--permission-mode acceptEdits` | Bypasses file edit prompts; confirms Bash commands | Routine refactoring of geometry libraries |
| Plan | `--permission-mode plan` | Strategic plan approval followed by autonomous execution | Multi-module feature implementation |
| bypassPermissions | `--dangerously-skip-permissions` | Complete unsupervised execution until task completion | Core driver for unattended CI/CD and self-healing cycles |

### Safe YOLO Environment

The `--dangerously-skip-permissions` flag represents a calculated trade-off between absolute safety and operational speed. This is characterized as a "Safe YOLO" environment when combined with **mandatory isolation**.

For Geometry OS, this means running the agent within:
- Locked-down Docker containers
- Virtual machines with snapshots
- Git worktrees for isolated branches

This ensures that even in catastrophic logic failures (e.g., misinterpreting "clean up" as deleting source directories), damage remains contained within a non-persistent workspace.

### Programmatic Invocation

For automation, Claude Code is invoked through non-interactive "print mode":

```bash
# Headless execution with JSON output for parsing
claude -p "Implement the holographic encoder" --output-format stream-json

# With permission bypass for autonomous runs
claude -p "Continue development" --dangerously-skip-permissions
```

The `--output-format stream-json` flag enables real-time monitoring of the agent's reasoning steps and tool usage.

---

## The Thin Agent Pattern

### Context Hygiene

The efficiency of the hierarchical model is predicated on the "Thin Agent" pattern. Individual worker agents are reduced to **stateless entities with minimal logic footprints**—often fewer than 150 lines of instructions.

This ensures the majority of the model's context window is dedicated to:
- Task-specific code
- Relevant file contents
- Error messages and logs

NOT to instructions about "how to be an agent."

### Agent Role Isolation

The architecture maintains strict separation between planning, execution, and verification roles. This prevents **Context Drift**, where an agent confuses requirements of a previous task with the current one.

| Agent Role | Responsibility | Context Persistence | Tool Access Profile |
|:-----------|:---------------|:--------------------|:--------------------|
| Goal Manager (Orchestrator) | Roadmap triage, phase scheduling | Long-term (Stateful) | Task, Git, File System |
| Research Specialist | Domain investigation, dependency mapping | Ephemeral (Stateless) | WebSearch, Grep, Read |
| Developer Worker | Code implementation, TDD | Ephemeral (Stateless) | Write, Bash (Test runners) |
| Auditor/Verifier | QA, security scan, spec compliance | Ephemeral (Stateless) | Read, Diff, Static Analyzers |

Every agent spawn creates a fresh instance with **zero shared history** from siblings. The Orchestrator selectively injects only necessary information into the worker's prompt.

---

## Component Specifications

### 1. TMUX Session Manager

The tmux session provides isolated, observable panes for the two-agent system.

```bash
# Session: geometry-auto
# Pane 0: claude (worker)
# Pane 1: planner (orchestrator - idle until triggered)
```

**Responsibilities**:
- Create and manage 2-pane tmux session
- Capture worker output for analysis
- Inject orchestrator prompts into worker pane
- Monitor for turn completion

### Terminal Vision

The ability to capture terminal state via `tmux capture-pane -p` gives agents a form of **"Terminal Vision"**. This allows agents to:

- Read logs and command outputs
- Capture state of full-screen applications (vim, htop, gdb)
- Read build output and stack traces
- Monitor REPL sessions

This is critical for self-healing loops. If a Geometry OS build fails, the agent captures the entire buffer, identifies the specific stack trace or compiler error, and formulates a plan to address it. This bypasses limitations of standard pipe-based redirection, which often fails for full-screen or readline-based tools.

```bash
# Capture worker pane output
tmux capture-pane -t geometry-auto:0 -p -S -500

# The -S flag scrolls back N lines
# The -p flag prints to stdout without affecting the pane
```

### 2. Worker Agent (Pane 0)

**Tool**: Claude Code CLI
**Mode**: Interactive (not --print)

**Behavior**:
- Accepts prompts from orchestrator
- Executes code changes, tests, file operations
- Reports completion status
- Runs until turn naturally ends

### 3. Orchestrator Agent (Pane 1)

**Primary Tool**: Gemini CLI
**Fallback Chain**: Gemini CLI → Claude Code (--print) → LM Studio API

**Responsibilities**:
- Analyze worker session output
- Check roadmap progress
- Detect loops and blockers
- Generate Mission Briefing
- Output next prompt with appropriate plugin

**System Prompt** (see ORCHESTRATOR_PROMPT.md):
```
You are the Orchestrator for Geometry OS autonomous development.

GOAL: Geometry OS must run Linux or have Linux-equivalent capabilities.

Your job is to analyze the worker session and determine the optimal next step.

INPUTS YOU RECEIVE:
- MISSION_BRIEFING.md: Current state and recent progress
- MANIFEST.yaml: Phase tracking and dirty bits
- PLUGINS.md: Available commands to invoke
- Recent worker output: Last N lines of Claude Code session

OUTPUT FORMAT:
Output ONLY the next prompt to send to the worker. This can be:
1. A plugin command: /gsd:execute-phase 14.2
2. A natural language prompt: "Continue implementing the holographic encoder"
3. A recovery prompt: "Tests are failing. Debug and fix the issue."

DO NOT explain your reasoning. Output ONLY the prompt.
```

---

## State Layer

### MANIFEST.yaml

Persistent source of truth for project progress.

```yaml
# .geometry/MANIFEST.yaml
meta:
  goal: "Geometry OS runs Linux or has Linux-equivalent capabilities"
  created: 2026-02-28
  last_updated: 2026-02-28T14:32:00Z
  version: 1

phase:
  current: "P"  # Current phase letter
  name: "Holographic Font Architecture"
  status: "in_progress"  # pending | in_progress | complete | blocked
  completion_pct: 45

task:
  current: "P.2.2"
  description: "Implement RGB steganography"
  status: "in_progress"

completion_promises:
  - id: "P.2.2"
    promise: "RGB_STEGANOGRAPHY_COMPLETE"
    status: "pending"
  - id: "P.3.1"
    promise: "FUSION_SHADER_COMPILES"
    status: "complete"

dirty_bits:
  code_modified: true
  tests_run: false
  tests_passing: null  # Must be true before phase complete
  docs_updated: false

safety:
  iteration_count: 12
  max_iterations: 100
  consecutive_failures: 0
  max_consecutive_failures: 3
  last_tool_signatures:
    - "Edit(file=holographic_encoder.py)"
    - "Bash(cmd=pytest tests/)"
  signature_history_depth: 10
  loop_detected: false

context:
  estimated_usage_pct: 72
  compaction_threshold: 85
  last_compaction: 2026-02-28T10:00:00Z
```

## Resource Constraints and the Compaction Gate

Context management is the ultimate bottleneck in agentic systems. As an agent works, its conversation history consumes tokens, leading to a **"Context-Capability Paradox"** where a smarter agent becomes less effective because it has too many instructions.

### Context Window Mathematics

The system enforces token hygiene programmatically. The current context usage (C) is calculated as:

```
C = cached_tokens + current_input
```

For a standard 200,000-token window, the **Compaction Gate** acts as a cognitive circuit breaker with three critical thresholds:

| Threshold | Tokens Used | Action |
|:----------|:------------|:-------|
| **Warning** | 75% (150K) | System issues warning, recommends `/compact` operation |
| **Mandatory** | 80% (160K) | System triggers mandatory compaction - agent must summarize session state to file and restart |
| **Hard Block** | 85% (170K) | Enforced by `compaction-gate-enforcement.sh` hook - prevents further tool calls until context cleared |

### Why This Matters

This gate ensures the "reasoning budget" is preserved for the task at hand, preventing **"hallucinated success"** that occurs when a model loses access to earlier instructions due to window sliding.

The gate is implemented as a deterministic hook that operates outside the LLM's reasoning loop:

```bash
# .geometry/hooks/compaction-gate-enforcement.sh
CONTEXT_PCT=$(estimate_context)
if [ "$CONTEXT_PCT" -gt 85 ]; then
  echo "HARD_BLOCK: Context at ${CONTEXT_PCT}%"
  echo "Run: /compact or restart session"
  exit 1
fi
```

---

## Multi-Model Fallback and Resilience Strategy

The autonomous improvement of Geometry OS cannot rely on a single model. Rate limits, API outages, or reasoning failures must be handled through a robust fallback mechanism.

### Fallback Chain

| Strategy | Engine | Operational Context | Capability Focus |
|:---------|:-------|:--------------------|:-----------------|
| Primary | Claude Code | Default State | Precision coding, complex refactors |
| Secondary | Gemini-1.5-Pro | API Overload / Planning stall | Large-scale research, self-healing |
| Tertiary | Gemini-1.5-Flash | Cost/Speed optimization | Minor bug fixes, boilerplate |
| Local | LM Studio / Llama 3 | Offline / Data Sensitive | Sensitive kernel/security modules |

### Gemini CLI "ReAct" Fallback

The Gemini CLI utilizes a "Reason and Act" (ReAct) loop. When Claude Code encounters:
- Persistent "Stop event"
- Failed verification gate more than 3 times
- Context exhaustion

The Orchestrator triggers the Gemini fallback. Gemini is particularly effective at **self-healing**—when it hits a wall, it proposes a new plan rather than simply failing.

### Local Model Integration

For scenarios requiring data sovereignty or offline operation, the system falls back to local models via LM Studio. The Orchestrator interacts through the OpenAI-compatible REST API:

```bash
# LM Studio fallback
curl http://localhost:1234/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "local-model", "messages": [...]}'
```

---

## Cryptographic Identity and Audit Trails

### Agentic JWTs

To address the "intent-execution separation problem," the system uses **Agentic JWTs**—tokens that include a SHA-256 cryptographic hash (Agent Checksum) of the agent's configuration:

```yaml
# In MANIFEST.yaml
identity:
  agent_checksum: "sha256:abc123..."  # Hash of system prompt + tools + model params
  workflow_binding: "correlation-id-xyz"  # Links changes to roadmap intent
  authorized_roles: ["developer", "tester"]
```

In the Geometry OS pipeline, this checksum ensures that only agents with a "Gold Standard" configuration are authorized to push changes to the kernel repository.

### Frozen Replays and MDP Evaluation

**Frozen Replays**: Every trajectory—including model versions, prompt hashes, and tool responses—is logged. This allows human architects to replay an exact autonomous session to understand why a specific decision was made.

**MDP-based Evaluation**: By treating OS evolution as a Markov Decision Process (MDP), the system tracks **Markovian coverage**—measuring how frequently agents visit critical state spaces (memory allocator, security subsystem). This enables continuous tuning of agent behavior.

```json
// .geometry/frozen_replay.json
{
  "session_id": "auto-2026-02-28-143200",
  "model_version": "claude-sonnet-4.6",
  "prompt_hash": "sha256:def456...",
  "trajectory": [
    {"state": "planning", "action": "read_roadmap", "next_state": "executing"},
    {"state": "executing", "action": "edit_file", "next_state": "testing"}
  ]
}
```

---

## State Layer

### MANIFEST.yaml

Runtime state for the current session.

```json
{
  "session_id": "auto-2026-02-28-143200",
  "started": "2026-02-28T14:32:00Z",
  "turn_count": 5,
  "recent_actions": [
    {
      "timestamp": "2026-02-28T14:35:00Z",
      "tool": "Edit",
      "args": {"file": "holographic_encoder.py"},
      "result": "success"
    },
    {
      "timestamp": "2026-02-28T14:36:00Z",
      "tool": "Bash",
      "args": {"cmd": "pytest tests/"},
      "result": "failure",
      "error": "3 tests failed"
    }
  ],
  "tool_signature_buffer": [
    "Edit(file=holographic_encoder.py)",
    "Bash(cmd=pytest tests/)"
  ],
  "failure_count": 0,
  "last_orchestrator_prompt": "/gsd:execute-phase P.2",
  "worker_output_buffer": "..."  # Last 500 lines
}
```

### MISSION_BRIEFING.md

Generated before each orchestrator invocation.

```markdown
# Mission Briefing - 2026-02-28T14:32:00Z

## Goal
Geometry OS runs Linux or has Linux-equivalent capabilities

## Current State
- **Phase**: P (Holographic Font Architecture)
- **Task**: P.2.2 - Implement RGB steganography
- **Progress**: 45% complete
- **Last Action**: Implemented Hadamard encoding in holographic_encoder.py
- **Context Usage**: 72%

## Recent Completions
- [x] P.1.1: TTF Generation Pipeline
- [x] P.2.1: Hadamard basis encoding

## Current Blockers
- None

## Dirty Bits Status
| Check | Status | Action Required |
|-------|--------|-----------------|
| Code modified | YES | - |
| Tests run | NO | ⚠️ Must run tests |
| Tests passing | NULL | - |

## Safety Status
- Iterations: 12/100
- Consecutive failures: 0/3
- Loop detected: No

## Recommended Next Step
Run tests to verify Hadamard encoding implementation:
```
/gsd:execute-phase P.2
```

## Alternative Paths
1. If tests fail: `/superpowers:systematic-debugging`
2. If stuck: `/ralph-specum:research` to investigate approach
3. If phase complete: `/gsd:progress` to get next phase
```

---

## Integrated Plugin Ecosystem

To enforce structured development methodology, the system incorporates four primary plugins. These are not merely shortcuts but represent **"Agent Skills"**—directories of instructions and resources that Claude loads on-demand.

### /gsd: Unified Roadmap and Phase Management

The "Get Shit Done" (GSD) framework is the primary vehicle for managing the Geometry OS roadmap. It focuses on preventing **"context rot"** by maintaining structured documentation for specifications, bugs, and milestones. GSD enforces a bidirectional pattern between human strategic intent and autonomous AI execution.

| GSD Command | Action | Output Artifacts |
|:------------|:-------|:-----------------|
| `/gsd:new-project` | Idea extraction and roadmap generation | PROJECT.md, ROADMAP.md, STATE.md |
| `/gsd:discuss-phase [N]` | Preference capture and gray-area resolution | {N}-CONTEXT.md |
| `/gsd:plan-phase [N]` | Domain research and task decomposition | {N}-RESEARCH.md, {N}-{M}-PLAN.md |
| `/gsd:progress` | Current status audit and next-step triage | CLI status report |
| `/gsd:execute-phase [N]` | Execute all plans in phase | Implementation artifacts |
| `/gsd:verify-work` | Validate completed features | Verification report |

The workflow starts with `/gsd:new-project`, which initializes PROJECT.md, ROADMAP.md, and STATE.md. For each phase, `/gsd:discuss-phase` captures preferences before code is written, ensuring agent research aligns with architect vision.

### /bmad: Agile Decomposition and Multi-Agent Solutioning

BMAD (Build More Architect Dreams) provides the agile engine for solutioning. It transforms roadmap phases into executable stories through a multi-agent workflow involving:

- Product Managers (`/pm`)
- Architects (`/arch`)
- Scrum Masters (`/sm`)
- Developers (`/dev`)
- QA Engineers (`/qa`)

Key capabilities:
- Creates PRDs that import into the implementation loop
- Generates technical plans and task breakdowns by user story
- Implementation proceeds autonomously using `/bmad-bmm-dev`

### /ralph-specum: The Execution Loop and Code Discovery

Ralph is the primary driver of the implementation phase, featuring a self-contained execution loop with a "stop-hook" mechanism.

**Key Features**:
- **Quick Mode** (`--quick`): Skips interactive interviews, immediately starts execution
- **Indexing**: `/ralph-specum:index` scans repository for services, models, helpers—generating searchable specs
- **Smart Compaction**: Combines Ralph Wiggum loop with structured specification workflow

For Geometry OS, Ralph's indexing ensures agents don't reinvent existing geometric primitives but build upon the established foundation.

### /superpowers: TDD and Quality Gates

Superpowers enforces the "Red-Green-Refactor" cycle and systematic debugging workflows. In Geometry OS, where mathematical precision is non-negotiable, Superpowers prevents agents from claiming tasks complete until rigorous verification.

**Hard Gates**:
- The `test-driven-development` skill will **delete code written before a failing test is established**
- Forces strict Red-Green-Refactor protocol
- Prevents "hallucinated success" through mandatory verification

| Skill | Enforcement Level |
|:------|:------------------|
| `test-driven-development` | Hard gate - deletes non-TDD code |
| `systematic-debugging` | Soft gate - recommends workflow |
| `verification-before-completion` | Hard gate - requires evidence |
| `brainstorming` | Required before new features |

---

## Reference Layer

### PLUGINS.md

Static reference of available plugins and when to use them.

```markdown
# Available Plugins for Geometry OS Development

## /superpowers (Core Workflows)

| Command | Use When | Example |
|---------|----------|---------|
| `brainstorming` | Starting new feature, need design exploration | `/superpowers:brainstorming` |
| `test-driven-development` | Implementing with tests first | `/superpowers:test-driven-development` |
| `systematic-debugging` | Tests failing, need diagnosis | `/superpowers:systematic-debugging` |
| `verification-before-completion` | Before claiming work is done | `/superpowers:verification-before-completion` |
| `executing-plans` | Have a written plan to execute | `/superpowers:executing-plans` |

## /ralph-specum (Spec-Driven Development)

| Command | Use When | Example |
|---------|----------|---------|
| `start` | Beginning new spec-driven feature | `/ralph-specum:start` |
| `research` | Need to investigate before implementing | `/ralph-specum:research` |
| `requirements` | Generate requirements from research | `/ralph-specum:requirements` |
| `design` | Create technical design | `/ralph-specum:design` |
| `tasks` | Generate implementation tasks | `/ralph-specum:tasks` |
| `implement` | Execute implementation tasks | `/ralph-specum:implement` |
| `status` | Check spec status | `/ralph-specum:status` |

## /gsd (Geometry OS Development - Phase Execution)

| Command | Use When | Example |
|---------|----------|---------|
| `plan-phase` | Need execution plan for a phase | `/gsd:plan-phase 14` |
| `execute-phase` | Ready to implement a phase | `/gsd:execute-phase 14` |
| `progress` | Check current project status | `/gsd:progress` |
| `verify-work` | Validate completed work | `/gsd:verify-work` |
| `debug` | Systematic debugging with state | `/gsd:debug` |
| `resume-work` | Resume from previous session | `/gsd:resume-work` |

## /bmad (Agile Methodology)

| Command | Use When | Example |
|---------|----------|---------|
| `bmm-dev` | Implement a user story | `/bmad-bmm-dev` |
| `bmm-qa` | Quality review needed | `/bmad-bmm-qa` |
| `bmm-create-story` | Create next story | `/bmad-bmm-create-story` |
| `bmm-sprint-planning` | Plan next sprint | `/bmad-bmm-sprint-planning` |
| `bmm-code-review` | Adversarial code review | `/bmad-bmm-code-review` |

## Selection Heuristics

```
IF starting fresh feature:
  → /superpowers:brainstorming OR /ralph-specum:start

IF have plan/spec:
  → /gsd:execute-phase OR /ralph-specum:implement

IF tests failing:
  → /superpowers:systematic-debugging

IF need to verify work:
  → /superpowers:verification-before-completion

IF phase complete:
  → /gsd:progress

IF stuck/blocked:
  → /ralph-specum:research OR /superpowers:brainstorming
```
```

### SAFETY_RULES.md

Deterministic safety mechanisms.

```markdown
# Safety Rules for Autonomous Loop

## Loop Detection

### Duplicate-Chain Detection
Monitor sequence of tool calls. If identical sequence appears 3+ times:
1. Pause execution
2. Invoke out-of-band advisor
3. Log to .geometry/safety_log.json

### Signature-Based Detection
Compare last N tool call signatures (function + normalized args):
- If 3+ identical signatures in buffer: SOFT_LOOP triggered
- If 5+ identical signatures: HARD_STOP triggered

## No-Progress Heuristic

If N (default: 3) consecutive iterations fail to progress:
1. Increment `consecutive_failures` in MANIFEST
2. If `consecutive_failures >= max_consecutive_failures`:
   - Pause for human intervention
   - Create BLOCKER_REPORT.md
   - Wait for manual reset

## Dirty Bit Checks

Before marking task complete, verify:

| Condition | Check | Required |
|-----------|-------|----------|
| Code modified | `tests_run == true` | Yes |
| Code modified | `tests_passing == true` | Yes |
| Tests failing | Cannot complete task | Yes |
| Phase ending | All tasks complete | Yes |

## Iteration Cap

Hard limit on iterations per session:
- Default: 100 iterations
- Configurable in MANIFEST.yaml
- When reached: Create CHECKPOINT.md and pause

## Context Compaction Gate

When context usage > 85%:
1. Force session termination
2. Generate summary of current work
3. Create fresh session with Mission Briefing
4. Continue from where left off

## Out-of-Band Advisor

When cognitive deadlock detected:
1. Spawn separate high-reasoning model (Claude Opus or LM Studio)
2. Provide full session transcript
3. Request analysis and new approach
4. Inject advisor's recommendation as system message
```

---

## Orchestrator Loop (Pseudo-code)

```bash
#!/bin/bash
# geometry_os_auto.sh

set -e

# Configuration
TMUX_SESSION="geometry-auto"
WORKER_PANE=0
ORCHESTRATOR_PANE=1
POLL_INTERVAL=5
TURN_END_THRESHOLD=30  # seconds of no activity

# Paths
GEOMETRY_DIR=".geometry"
MANIFEST="$GEOMETRY_DIR/MANIFEST.yaml"
SESSION_STATE="$GEOMETRY_DIR/session_state.json"
MISSION_BRIEFING="$GEOMETRY_DIR/MISSION_BRIEFING.md"
PLUGINS_REF="docs/designs/PLUGINS.md"
ROADMAP="UNIFIED_ROADMAP_2026.md"

# Fallback chain
ORCHESTRATOR_CMD=("gemini" "claude --print" "lm-studio-complete")

# ============================================================================
# INITIALIZATION
# ============================================================================

init_tmux() {
  if ! tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
    tmux new-session -d -s "$TMUX_SESSION" -x 200 -y 50
    tmux split-window -h -t "$TMUX_SESSION"

    # Pane 0: Worker (Claude Code)
    tmux send-keys -t "$TMUX_SESSION:$WORKER_PANE" "claude" Enter

    # Pane 1: Orchestrator (idle)
    tmux send-keys -t "$TMUX_SESSION:$ORCHESTRATOR_PANE" "# Orchestrator ready" Enter

    log "Created tmux session: $TMUX_SESSION"
  fi
}

init_state() {
  mkdir -p "$GEOMETRY_DIR"

  if [ ! -f "$MANIFEST" ]; then
    cat > "$MANIFEST" << EOF
meta:
  goal: "Geometry OS runs Linux or has Linux-equivalent capabilities"
  created: $(date -Iseconds)
  last_updated: $(date -Iseconds)
  version: 1

phase:
  current: "A"
  status: "pending"
  completion_pct: 0

safety:
  iteration_count: 0
  max_iterations: 100
  consecutive_failures: 0
  max_consecutive_failures: 3
  last_tool_signatures: []
  loop_detected: false
EOF
  fi

  echo '{}' > "$SESSION_STATE"
}

# ============================================================================
# CAPTURE
# ============================================================================

capture_worker_output() {
  tmux capture-pane -t "$TMUX_SESSION:$WORKER_PANE" -p -S -500
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
  echo "$output" | grep -oE '(Edit|Bash|Read|Write|Grep|Glob)\([^)]+\)' | tail -10
}

get_last_activity_time() {
  local output="$1"
  # Look for timestamps or assume now
  date +%s
}

# ============================================================================
# DETECTION
# ============================================================================

is_turn_end() {
  local output="$1"
  local last_activity="$2"

  # Check for explicit completion markers
  if echo "$output" | tail -20 | grep -qE "(TASK_COMPLETE|Done|Finished|Complete)"; then
    return 0
  fi

  # Check for inactivity (no new output for N seconds)
  local now=$(date +%s)
  local elapsed=$((now - last_activity))
  if [ "$elapsed" -gt "$TURN_END_THRESHOLD" ]; then
    return 0
  fi

  return 1
}

is_looping() {
  local signatures="$1"
  local signature_array=($signatures)

  # Check for 3+ identical consecutive signatures
  local last_sig=""
  local count=0

  for sig in "${signature_array[@]}"; do
    if [ "$sig" == "$last_sig" ]; then
      ((count++))
      if [ "$count" -ge 3 ]; then
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
  local threshold=$(yaml_read "$MANIFEST" ".context.compaction_threshold" 85)

  if [ "$context_pct" -gt "$threshold" ]; then
    return 0  # Needs compaction
  fi
  return 1
}

check_dirty_bits() {
  local code_modified=$(yaml_read "$MANIFEST" ".dirty_bits.code_modified" false)
  local tests_run=$(yaml_read "$MANIFEST" ".dirty_bits.tests_run" false)

  if [ "$code_modified" == "true" ] && [ "$tests_run" == "false" ]; then
    return 0  # Dirty: must run tests
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
  local current_phase=$(yaml_read "$MANIFEST" ".phase.current" "A")
  local current_task=$(yaml_read "$MANIFEST" ".task.current" "unknown")
  local iteration=$(yaml_read "$MANIFEST" ".safety.iteration_count" 0)
  local failures=$(yaml_read "$MANIFEST" ".safety.consecutive_failures" 0)

  cat > "$MISSION_BRIEFING" << EOF
# Mission Briefing - $(date -Iseconds)

## Goal
Geometry OS runs Linux or has Linux-equivalent capabilities

## Current State
- **Phase**: $current_phase
- **Task**: $current_task
- **Context Usage**: ${context_pct}%

## Recent Worker Output (last 50 lines)
\`\`\`
$(echo "$worker_output" | tail -50)
\`\`\`

## Safety Status
- Iterations: $iteration/100
- Consecutive failures: $failures/3

## Available Plugins
See: $PLUGINS_REF
EOF

  echo "$MISSION_BRIEFING"
}

run_orchestrator() {
  local mission_briefing="$1"
  local next_prompt=""

  for cmd in "${ORCHESTRATOR_CMD[@]}"; do
    log "Trying orchestrator: $cmd"

    next_prompt=$($cmd << EOF 2>/dev/null
You are the Orchestrator for Geometry OS autonomous development.

GOAL: Geometry OS must run Linux or have Linux-equivalent capabilities.

Read the Mission Briefing and output ONLY the next prompt to send to the worker.

$(cat "$mission_briefing")

OUTPUT FORMAT:
- A plugin command: /gsd:execute-phase 14.2
- A natural language prompt: "Continue implementing the holographic encoder"
- A recovery prompt: "Tests are failing. Debug and fix the issue."

Output ONLY the prompt, nothing else.
EOF
) && break

    log "Orchestrator $cmd failed, trying next..."
  done

  echo "$next_prompt"
}

invoke_out_of_band_advisor() {
  log "Invoking out-of-band advisor for cognitive deadlock..."

  local transcript=$(capture_worker_output)

  # Use Claude Opus or LM Studio for higher reasoning
  local advice=$(claude --model claude-opus-4-6 --print << EOF
You are an Out-of-Band Advisor. The autonomous loop is stuck.

TRANSCRIPT:
$transcript

Analyze the cognitive deadlock and provide:
1. Root cause of the stuck state
2. A completely different approach to try
3. The exact prompt to inject

Output the prompt to inject, nothing else.
EOF
)

  echo "$advice"
}

# ============================================================================
# INJECTION
# ============================================================================

inject_prompt() {
  local prompt="$1"

  log "Injecting prompt: $prompt"
  tmux send-keys -t "$TMUX_SESSION:$WORKER_PANE" "$prompt" Enter
}

# ============================================================================
# STATE UPDATES
# ============================================================================

update_manifest() {
  local field="$1"
  local value="$2"

  # Use yq or python to update YAML
  python3 -c "
import yaml
with open('$MANIFEST', 'r') as f:
    data = yaml.safe_load(f)
data$field = $value
data['meta']['last_updated'] = '$(date -Iseconds)'
with open('$MANIFEST', 'w') as f:
    yaml.dump(data, f)
"
}

update_session_state() {
  local tool_sig="$1"
  local result="$2"

  python3 -c "
import json
from datetime import datetime

with open('$SESSION_STATE', 'r') as f:
    data = json.load(f)

data['recent_actions'].append({
    'timestamp': datetime.now().isoformat(),
    'tool_signature': '$tool_sig',
    'result': '$result'
})

# Keep only last 50 actions
data['recent_actions'] = data['recent_actions'][-50:]

with open('$SESSION_STATE', 'w') as f:
    json.dump(data, f, indent=2)
"
}

# ============================================================================
# MAIN LOOP
# ============================================================================

log() {
  echo "[$(date -Iseconds)] $1" | tee -a "$GEOMETRY_DIR/loop.log"
}

main() {
  log "Starting Geometry OS Autonomous Loop"
  log "Goal: Geometry OS runs Linux or has Linux-equivalent capabilities"

  init_tmux
  init_state

  local last_activity=$(date +%s)
  local last_output=""

  while true; do
    # 1. CAPTURE
    local worker_output=$(capture_worker_output)
    local context_pct=$(estimate_context_usage "$worker_output")
    local tool_sigs=$(extract_tool_signatures "$worker_output")

    # Detect if output changed (activity)
    if [ "$worker_output" != "$last_output" ]; then
      last_activity=$(date +%s)
      last_output="$worker_output"
    fi

    # 2. DETECT TURN END
    if is_turn_end "$worker_output" "$last_activity"; then
      log "Turn ended, starting judgment phase..."

      # 2a. COMPACTION GATE
      if check_compaction_gate "$context_pct"; then
        log "Context at ${context_pct}%, triggering compaction handoff"
        generate_mission_briefing "$worker_output" "$context_pct"
        # Kill and restart worker with fresh context
        tmux send-keys -t "$TMUX_SESSION:$WORKER_PANE" C-c
        sleep 2
        tmux send-keys -t "$TMUX_SESSION:$WORKER_PANE" "claude" Enter
        sleep 5
        local briefing_prompt="Read .geometry/MISSION_BRIEFING.md and continue from where we left off."
        inject_prompt "$briefing_prompt"
        continue
      fi

      # 2b. LOOP DETECTION
      if is_looping "$tool_sigs"; then
        log "Loop detected!"
        update_manifest "['safety']['loop_detected']" "true"

        local advice=$(invoke_out_of_band_advisor)
        inject_prompt "$advice"
        continue
      fi

      # 2c. DIRTY BIT CHECK
      if check_dirty_bits; then
        log "Dirty bits detected: code modified but tests not run"
        inject_prompt "You modified code but haven't run tests. Run tests now with: pytest tests/"
        continue
      fi

      # 3. JUDGMENT
      generate_mission_briefing "$worker_output" "$context_pct"
      local next_prompt=$(run_orchestrator "$MISSION_BRIEFING")

      # 4. INJECT
      if [ -n "$next_prompt" ]; then
        inject_prompt "$next_prompt"

        # 5. UPDATE STATE
        update_manifest "['safety']['iteration_count']" "$(yaml_read "$MANIFEST" ".safety.iteration_count" 0) + 1"
      fi

      # Reset activity timer
      last_activity=$(date +%s)
    fi

    # Check for stop signal
    if [ -f "$GEOMETRY_DIR/STOP" ]; then
      log "Stop signal received, shutting down..."
      rm "$GEOMETRY_DIR/STOP"
      break
    fi

    sleep "$POLL_INTERVAL"
  done

  log "Autonomous loop ended"
}

# Run
main "$@"
```

---

## File Structure

```
geometry_os/
├── .geometry/
│   ├── MANIFEST.yaml           # Source of truth for progress
│   ├── session_state.json      # Runtime session state
│   ├── MISSION_BRIEFING.md     # Generated handoff doc
│   ├── BLOCKER_REPORT.md       # Created when stuck
│   ├── CHECKPOINT.md           # Created at iteration cap
│   ├── loop.log                # Execution log
│   ├── safety_log.json         # Safety event log
│   ├── frozen_replay.json      # Audit trail for decisions
│   └── hooks/
│       └── compaction-gate-enforcement.sh  # Context gate hook
│
├── docs/
│   └── designs/
│       ├── AUTONOMOUS_LOOP_DESIGN.md  # This document
│       ├── AUTONOMOUS_LOOP_QUICKSTART.md  # Quick start guide
│       ├── PLUGINS.md                  # Plugin reference
│       ├── SAFETY_RULES.md             # Safety mechanisms
│       └── ORCHESTRATOR_PROMPT.md      # Orchestrator system prompt
│
├── scripts/
│   └── geometry_os_auto.sh     # Main orchestrator script
│
├── ~/.claude/
│   └── settings.json           # Global Claude Code settings
│       # Contains: allowedTools, disallowedTools, hooks
│
└── UNIFIED_ROADMAP_2026.md     # Project roadmap
```

### Settings Configuration

The `~/.claude/settings.json` file controls the hierarchical configuration:

```json
{
  "allowedTools": ["Bash(git *)", "Read", "Edit", "Write"],
  "disallowedTools": ["Bash(rm -rf /*)", "Bash(sudo *)"],
  "hooks": {
    "PostToolUse": ".geometry/hooks/compaction-gate-enforcement.sh"
  }
}
```

This enforces a **"least privilege"** model even during fully autonomous runs.

---

## Getting Started

### 1. Create Required Files

```bash
# Create directories
mkdir -p .geometry docs/designs scripts

# Create initial MANIFEST
cat > .geometry/MANIFEST.yaml << 'EOF'
meta:
  goal: "Geometry OS runs Linux or has Linux-equivalent capabilities"
  created: 2026-02-28
  version: 1

phase:
  current: "A"
  status: "pending"

safety:
  iteration_count: 0
  max_iterations: 100
  consecutive_failures: 0
EOF
```

### 2. Start the Loop

```bash
chmod +x scripts/geometry_os_auto.sh
./scripts/geometry_os_auto.sh
```

### 3. Monitor Progress

```bash
# Attach to tmux session
tmux attach -t geometry-auto

# Watch logs
tail -f .geometry/loop.log

# Check current state
cat .geometry/MANIFEST.yaml
```

### 4. Stop the Loop

```bash
# Create stop signal
touch .geometry/STOP

# Or from inside tmux: Ctrl+C in orchestrator pane
```

---

## Future Enhancements

1. **Web Dashboard**: Real-time visualization of loop progress
2. **Multi-Worker**: Parallel workers for independent tasks
3. **Learning System**: Track successful patterns and avoid failed ones
4. **Human Approval Gates**: Optional checkpoints for risky operations
5. **Integration with Evolution Daemon**: Hook into existing self-improvement system

---

## References

- [Cognitive Architectures for Persistent Autonomy](https://arxiv.org/html/2602.10479)
- [Orchestrator-Worker Agents Comparison](https://arize.com/blog/orchestrator-worker-agents/)
- [Effective Context Engineering for AI Agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)
- [Deterministic AI Orchestration](https://www.praetorian.com/blog/deterministic-ai-orchestration/)
- [Claude Code Permission Modes](https://www.ksred.com/claude-code-dangerously-skip-permissions/)
- [Gemini CLI Documentation](https://github.com/google-gemini/gemini-cli)
- [GSD Framework](https://github.com/gsd-build/get-shit-done)
- [BMAD Method](https://github.com/bmad-code-org/BMAD-METHOD)
- [Smart Ralph Plugin](https://github.com/tzachbon/smart-ralph)
- [Superpowers Plugin](https://github.com/obra/superpowers)
- [Agentic JWT Specification](https://www.ietf.org/archive/id/draft-goswami-agentic-jwt-00.html)
- [Tmux MCP Server](https://skywork.ai/skypage/en/ai-agent-tmux-server/)

---

*Created: 2026-02-28*
*Version: 2.0*
*Updated: 2026-02-28*
