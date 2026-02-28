# Geometry OS Auto

> **Claude Code plugin for autonomous, continuous development of Geometry OS**

A two-agent orchestrator-worker architecture enabling autonomous, continuous development of Geometry OS toward Linux-capability.

## Features

- **Orchestrator-Worker Pattern**: Gemini CLI orchestrator + Claude Code worker
- **Terminal Persistence**: tmux session management for visibility
- **Multi-Model Fallback**: Claude Code → Gemini CLI → LM Studio
- **Comprehensive Plugin Reference**: /superpowers, /ralph-specum, /gsd, /bmad
- **Safety Mechanisms**: Loop detection, dirty bit checks, context gates
- **Cryptographic Identity**: Agentic JWTs for audit trails
- **Frozen Replays**: Full decision audit trail

## Quick Start

```bash
./scripts/geometry_os_auto.sh
```

## Documentation

- [AUTONOMOUS_LOOP_DESIGN.md](docs/designs/) - Full architecture
- [PLUGINS.md](docs/designs/) - Complete plugin reference
- [SAFETY_RULEs.md](docs/designs/) - Safety mechanisms
- [ORCHESTRATOR_PROMPT.md](docs/designs/) - System prompts
- [AUTONOMOUS_LOOP_quickstart.md](docs/designs/) - Quick reference

## Configuration

Edit `.geometry/MANIFEST.yaml` to set:
- Project goal
- Current phase
- Safety thresholds
- Context management

## Goal

**Geometry OS must run Linux or has Linux-equivalent capabilities.**
