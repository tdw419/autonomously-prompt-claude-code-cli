# Safety Rules for Autonomous Loop

> Deterministic safety mechanisms that operate outside the LLM's reasoning loop.

---

## Loop Detection

### Duplicate-Chain Detection

Monitor the sequence of tool calls. If an identical sequence appears multiple times:

```python
# Pseudo-code
def detect_loop(tool_signatures, window=10, threshold=3):
    """
    Check if same tool signature appears threshold+ times in window.
    """
    recent = tool_signatures[-window:]
    for sig in set(recent):
        if recent.count(sig) >= threshold:
            return True, sig
    return False, None
```

**Actions when detected**:
1. Pause execution
2. Log to `.geometry/safety_log.json`
3. Invoke out-of-band advisor
4. Do NOT continue until advisor provides new approach

### Signature-Based Detection

Compare the last N tool call signatures (function name + normalized arguments):

| Detection Level | Condition | Action |
|-----------------|-----------|--------|
| SOFT_LOOP | 3 identical signatures | Log warning, continue monitoring |
| HARD_LOOP | 5 identical signatures | Pause, invoke advisor |
| INFINITE_LOOP | 10+ identical signatures | Full stop, create BLOCKER_REPORT.md |

**Signature Normalization**:
```python
def normalize_signature(tool, args):
    """
    Edit(file=/path/to/foo.py, ...) → Edit(file=foo.py)
    Bash(cmd=pytest tests/unit/test_foo.py) → Bash(cmd=pytest tests/*)
    """
    if tool == "Edit":
        return f"Edit(file={basename(args.get('file', ''))})"
    if tool == "Bash":
        cmd = args.get('cmd', '')
        # Normalize file paths
        return f"Bash(cmd={normalize_paths(cmd)})"
    return f"{tool}(...)"
```

---

## No-Progress Heuristic

If N consecutive iterations fail to move the task forward:

```yaml
# In MANIFEST.yaml
safety:
  consecutive_failures: 0
  max_consecutive_failures: 3
```

**What counts as "failure"**:
- Tests fail after code change
- Build fails
- Same error appears twice
- No files modified in iteration

**Actions**:
1. Increment `consecutive_failures`
2. If `consecutive_failures >= max_consecutive_failures`:
   - Pause for human intervention
   - Create `BLOCKER_REPORT.md`
   - Wait for manual reset (delete `.geometry/BLOCKER_REPORT.md`)

---

## Dirty Bit Checks

Before marking any task complete, verify these conditions:

| Dirty Bit | Condition | Required Value | Check |
|-----------|-----------|----------------|-------|
| `code_modified` | Any Edit/Write tool used | N/A | Just tracks state |
| `tests_run` | `code_modified == true` | `true` | Must run pytest |
| `tests_passing` | `tests_run == true` | `true` | All tests pass |
| `docs_updated` | API/behavior changed | `true` | Update relevant docs |

**Enforcement**:
```python
def can_complete_task(manifest):
    dirty = manifest['dirty_bits']

    if dirty['code_modified'] and not dirty['tests_run']:
        return False, "Must run tests after code modification"

    if dirty['tests_run'] and not dirty['tests_passing']:
        return False, "Cannot complete task with failing tests"

    return True, None
```

**Auto-Prompt on Dirty Bit Violation**:
```
You modified code but haven't run tests. Run tests now with: pytest tests/
```

---

## Iteration Cap

Hard limit on iterations per session to prevent runaway execution:

```yaml
safety:
  iteration_count: 12
  max_iterations: 100
```

**When reached**:
1. Create `CHECKPOINT.md` with current state
2. Pause execution
3. Require human acknowledgment to continue

**CHECKPOINT.md format**:
```markdown
# Checkpoint - 2026-02-28T15:30:00Z

## Reason
Reached iteration cap: 100/100

## Current State
- Phase: P
- Task: P.2.2
- Last action: Running tests

## Progress Summary
- Files modified: 5
- Tests run: 12
- Tests passing: 10

## To Continue
Delete this file to resume: rm .geometry/CHECKPOINT.md
```

---

## Context Compaction Gate

The context window is the ultimate bottleneck in agentic systems. The **Compaction Gate** acts as a cognitive circuit breaker with three critical thresholds based on a standard 200,000-token window.

### Thresholds

| Threshold | Tokens Used | Action |
|:----------|:------------|:-------|
| **Warning** | 75% (150K) | System issues warning, recommends `/compact` operation |
| **Mandatory** | 80% (160K) | System triggers mandatory compaction - agent must summarize session state to file and restart |
| **Hard Block** | 85% (170K) | Enforced by `compaction-gate-enforcement.sh` hook - prevents further tool calls until context cleared |

### Why This Matters

This gate ensures the "reasoning budget" is preserved for the task at hand, preventing **"hallucinated success"** that occurs when a model loses access to earlier instructions due to window sliding.

### Context Mathematics

```
Context Usage (C) = cached_tokens + current_input
```

For a 200K token window:
- 75% = 150K tokens
- 80% = 160K tokens
- 85% = 170K tokens

### Hook Implementation

```bash
# .geometry/hooks/compaction-gate-enforcement.sh
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
      echo "HARD_BLOCK: Context at ${CONTEXT_PCT}%"
      echo "Run: /compact or restart session"
      exit 1
    fi
    ;;
esac
```

### Context Estimation

```python
def estimate_context(output_lines):
    """
    Rough heuristic for context usage.
    500 lines ≈ 70% context (varies by model)
    """
    return min(100, int(output_lines * 70 / 500))
```

### When Compaction Triggered

1. Force session termination (Ctrl+C in worker pane)
2. Generate `MISSION_BRIEFING.md` with summary
3. Start fresh Claude Code session
4. Inject briefing prompt: "Read .geometry/MISSION_BRIEFING.md and continue"

---

## Model Fallback Strategy

When the primary model fails, use fallbacks and invoke out-of-band advisor.

When Claude Code encounters:
- Persistent "Stop event"
- Failed verification gate more than 3 times
- Context exhaustion

The Orchestrator triggers the Gemini fallback.

### Fallback Chain

| Priority | Engine | Context | Use Case |
|:---------|:-------|:--------|:---------|
| Primary | Claude Code | Default | Precision coding, complex refactors |
| Secondary | Gemini-1.5-Pro | API overload | Large-scale research, self-healing |
| Tertiary | Gemini-1.5-Flash | Cost optimization | Minor bug fixes, boilerplate |
| Local | LM Studio / Llama 3 | Offline | Sensitive kernel/security modules |

### Self-Healing Behavior

Gemini CLI is particularly effective at self-healing—when it hits a wall, it **proposes a new plan** rather than simply failing. This is crucial for Geometry OS development where dead-ends are common.

---

## Out-of-Band Advisor

When cognitive deadlock is detected (loop, repeated failures, etc.):

```python
def invoke_advisor(transcript, deadlock_type):
    """
    Spawn separate high-reasoning model to analyze deadlock.
    """
    prompt = f"""
You are an Out-of-Band Advisor. The autonomous loop is stuck.

DEADLOCK TYPE: {deadlock_type}

TRANSCRIPT (last 500 lines):
{transcript}

Analyze the cognitive deadlock and provide:
1. Root cause of the stuck state
2. A completely different approach to try
3. The exact prompt to inject into the worker

Output ONLY the prompt to inject, nothing else.
"""

    # Use different, possibly more capable model
    return call_model(prompt, model="claude-opus-4-6")
```

**Advisor Model Priority**:
1. Claude Opus 4.6 (highest reasoning)
2. LM Studio with high-parameter model
3. Gemini Pro (if available)

---

## Zero-Trust Drift Prevention

The continuous improvement of Geometry OS must be balanced against the risk of **"Zero-Trust Drift"**, where the agent's actions diverge from human intent.

### Agentic Identity

Every agent configuration includes a cryptographic checksum:

```yaml
identity:
  agent_checksum: "sha256:abc123..."
  workflow_binding: "correlation-id-xyz"
  authorized_roles: ["developer", "tester"]
```

This ensures only agents with "Gold Standard" configurations can push changes to critical repositories.

### Frozen Replays

Every trajectory is logged for audit:

```json
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

This allows human architects to **replay exact autonomous sessions** to understand why specific decisions were made.

---

## Safety Event Log

All safety events are logged to `.geometry/safety_log.json`:

```json
{
  "events": [
    {
      "timestamp": "2026-02-28T15:30:00Z",
      "type": "SOFT_LOOP",
      "details": {
        "signature": "Edit(file=holographic_encoder.py)",
        "count": 3
      },
      "action_taken": "continued_monitoring"
    },
    {
      "timestamp": "2026-02-28T15:35:00Z",
      "type": "DIRTY_BIT_VIOLATION",
      "details": {
        "code_modified": true,
        "tests_run": false
      },
      "action_taken": "injected_test_prompt"
    },
    {
      "timestamp": "2026-02-28T15:40:00Z",
      "type": "COMPACTION_GATE",
      "details": {
        "context_pct": 87,
        "threshold": 85
      },
      "action_taken": "restarted_session"
    }
  ]
}
```

---

## Manual Override

### Stop the Loop
```bash
touch .geometry/STOP
```

### Pause for Review
```bash
touch .geometry/PAUSE
```

### Reset Failure Counter
```bash
# Edit MANIFEST.yaml
yq '.safety.consecutive_failures = 0' -i .geometry/MANIFEST.yaml
```

### Clear Blocker
```bash
rm .geometry/BLOCKER_REPORT.md
```

### Skip Dirty Bit Check (Dangerous!)
```bash
# Edit MANIFEST.yaml
yq '.dirty_bits.tests_run = true | .dirty_bits.tests_passing = true' -i .geometry/MANIFEST.yaml
```

---

## Configuration Reference

```yaml
# .geometry/MANIFEST.yaml - Safety section

safety:
  # Iteration limits
  iteration_count: 0
  max_iterations: 100

  # Failure tolerance
  consecutive_failures: 0
  max_consecutive_failures: 3

  # Loop detection
  last_tool_signatures: []
  signature_history_depth: 10
  soft_loop_threshold: 3
  hard_loop_threshold: 5

  # State
  loop_detected: false

context:
  estimated_usage_pct: 0
  # Three-tier thresholds
  warning_threshold: 75
  mandatory_threshold: 80
  hard_block_threshold: 85
  last_compaction: null

dirty_bits:
  code_modified: false
  tests_run: false
  tests_passing: null
  docs_updated: false

identity:
  agent_checksum: null
  workflow_binding: null
  authorized_roles: ["developer"]
```

---

*Last updated: 2026-02-28*
*Version: 2.0*
