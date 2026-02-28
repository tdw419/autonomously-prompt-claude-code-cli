# Available Plugins for Geometry OS Development

> Comprehensive reference for orchestrator agent to select appropriate commands.

---

## /superpowers (Core Workflows)

Enforces the "Red-Green-Refactor" cycle and systematic debugging workflows. Prevents agents from claiming tasks complete until rigorous verification.

### Core Workflow Skills

| Command | Use When | Enforcement |
|---------|----------|-------------|
| `brainstorming` | Starting new feature, need design exploration | Required before new features |
| `test-driven-development` | Implementing with tests first | Hard gate - deletes non-TDD code |
| `systematic-debugging` | Tests failing, need diagnosis | Soft gate - recommends workflow |
| `verification-before-completion` | Before claiming work is done | Hard gate - requires evidence |
| `executing-plans` | Have a written plan to execute | Soft gate |
| `writing-plans` | Need to create implementation plan | Soft gate |
| `receiving-code-review` | Got feedback to address | Soft gate |
| `requesting-code-review` | Need code reviewed | Soft gate |
| `dispatching-parallel-agents` | Have 2+ independent tasks | Soft gate |
| `finishing-a-development-branch` | Implementation complete, need to integrate | Soft gate |
| `subagent-driven-development` | Executing plans with independent tasks | Soft gate |
| `using-git-worktrees` | Starting feature work needing isolation | Soft gate |

### Superpowers Behavior

- **Hard Gates**: Skills that enforce mandatory behavior (e.g., TDD deletes code written before tests)
- **Soft Gates**: Skills that recommend but don't enforce
- **Required Invocation**: `brainstorming` MUST be called before any creative work

---

## /ralph-specum (Spec-Driven Development)

Primary driver of the implementation phase. Features a self-contained execution loop with "stop-hook" mechanism.

### Spec Lifecycle Skills

| Command | Use When | Output |
|---------|----------|--------|
| `start` | Beginning new spec-driven feature | Creates spec structure |
| `new` | Create new spec and start research | New spec directory |
| `research` | Need to investigate before implementing | RESEARCH.md |
| `requirements` | Generate requirements from research | requirements.md |
| `design` | Create technical design | design.md |
| `tasks` | Generate implementation tasks | tasks.md |
| `implement` | Execute implementation tasks | Code changes |
| `status` | Check spec status | Status report |
| `refactor` | Update specs methodically after execution | requirements → design → tasks |
| `cancel` | Cancel active execution loop | Cleanup state |

### Quick Mode

| Command | Use When | Behavior |
|---------|----------|----------|
| `start --quick` | Skip interviews, auto-generate artifacts | Immediate execution |
| `research --quick` | Quick research phase | Auto-generates research |

### Code Discovery & Meta

| Command | Use When | Output |
|---------|----------|--------|
| `index` | Scan repository for components | Searchable specs |
| `smart-ralph` | Get help with Ralph arguments | Usage guide |
| `interview-framework` | Standard adaptive interview loop | Internal logic guide |
| `communication-style` | Rules for concise, scannable output | Formatting rules |
| `delegation-principle` | Coordination and subagent delegation | Role guidance |
| `reality-verification` | Verify fixes, diagnose issues | Evidence criteria |
| `feedback` | Report issues or submit feedback | Feedback loop |
| `spec-workflow` | Start a new feature or spec | `/ralph-specum:start` |

### Ralph Special Features

- **Stop-Hook Mechanism**: Allows agent to move through tasks without external dependencies
- **Quick Mode** (`--quick`): Skips interactive interviews, immediately starts execution
- **Indexing**: Scans repository for services, models, helpers—generating searchable specs
- **Reality Verification**: Use for "verify a fix", "reproduce failure", "diagnose issue", "check BEFORE/AFTER state"
- **Smart Compaction**: Combines Ralph Wiggum loop with structured specification workflow

---

## /gsd (Geometry OS Development - Phase Execution)

Primary vehicle for managing the Geometry OS roadmap. Prevents "context rot" by maintaining structured documentation.

### Project Management Skills

| Command | Use When | Output |
|---------|----------|--------|
| `new-project` | Initialize new project | PROJECT.md, ROADMAP.md, STATE.md |
| `new-milestone` | Start new milestone cycle | Updated PROJECT.md |
| `progress` | Check current project status | CLI status report |
| `add-phase` | Add phase to end of roadmap | Updated ROADMAP.md |
| `insert-phase` | Insert urgent work as decimal phase | Phase N.M |
| `remove-phase` | Remove future phase from roadmap | Updated ROADMAP.md |
| `map-codebase` | Analyze codebase structure | .planning/codebase/ documents |

### Phase Execution Skills

| Command | Use When | Output |
|---------|----------|--------|
| `discuss-phase` | Gather context before planning | {N}-CONTEXT.md |
| `list-phase-assumptions` | Surface assumptions about approach | Assumptions list |
| `research-phase` | Research how to implement phase | RESEARCH.md |
| `plan-phase` | Create execution plan for phase | PLAN.md |
| `execute-phase` | Execute all plans in phase | Implementation artifacts |
| `verify-work` | Validate completed features | Verification report |

### Workflow Skills

| Command | Use When | Output |
|---------|----------|--------|
| `resume-work` | Resume from previous session | Context restoration |
| `pause-work` | Create context handoff | Handoff document |
| `debug` | Systematic debugging with state | Debug session |
| `check-todos` | List pending todos | Todo list |
| `add-todo` | Capture idea from conversation | New todo |
| `settings` | Configure GSD workflow | Settings update |
| `set-profile` | Switch model profile | Profile change |

### Milestone Skills

| Command | Use When | Output |
|---------|----------|--------|
| `audit-milestone` | Audit completion before archiving | Audit report |
| `complete-milestone` | Archive completed milestone | Archive |
| `plan-milestone-gaps` | Create phases to close gaps | New phases |

### Utility Skills

| Command | Use When | Output |
|---------|----------|--------|
| `help` | Show available commands | Usage guide |
| `whats-new` | See what's new in GSD | Changelog |
| `update` | Update GSD to latest version | Update |

### GSD Profile Options

| Profile | Model | Use When |
|---------|-------|----------|
| `quality` | Higher capability | Complex phases |
| `balanced` | Mixed | Default |
| `budget` | Faster, cheaper | Simple phases |

---

## /bmad (Agile Methodology)

Agile engine for solutioning. Transforms roadmap phases into executable stories through multi-agent workflow.

### Product Management Skills

| Command | Use When | Output |
|---------|----------|--------|
| `bmm-create-product-brief` | Create product brief through discovery | Product brief |
| `bmm-create-prd` | Create product requirements document | PRD |
| `bmm-edit-prd` | Edit existing PRD | Updated PRD |
| `bmm-validate-prd` | Validate PRD against standards | Validation report |
| `bmm-market-research` | Market research on competition/customers | Research report |
| `bmm-domain-research` | Domain and industry research | Research report |
| `bmm-technical-research` | Research technologies and architecture | Research report |
| `bmm-document-project` | Document brownfield projects | Project docs |
| `bmm-generate-project-context` | Create project-context.md with AI rules | Context file |

### Planning Skills

| Command | Use When | Output |
|---------|----------|--------|
| `bmm-create-architecture` | Create technical architecture | Architecture doc |
| `bmm-create-ux-design` | Plan UX patterns and design specs | UX design |
| `bmm-create-epics-and-stories` | Break requirements into epics/stories | Story list |
| `bmm-create-story` | Create dedicated story file | Story file |
| `bmm-create-next-story` | Create next story in sprint | Story file |
| `bmm-sprint-planning` | Generate sprint status from epics | Sprint plan |
| `bmm-sprint-status` | Summarize sprint and surface risks | Status report |
| `bmm-check-implementation-readiness` | Validate PRD/UX/Architecture complete | Readiness report |

### Development Skills

| Command | Use When | Output |
|---------|----------|--------|
| `bmm-dev` | Implement a user story | Code changes |
| `bmm-quick-dev` | Implement quick tech spec | Code changes |
| `bmm-quick-spec` | Create implementation-ready quick spec | Quick spec |
| `bmm-dev-story` | Execute story implementation | Story completion |
| `bmm-code-review` | Adversarial code review | Review findings |
| `bmm-qa` | Quality review needed | QA report |
| `bmm-qa-generate-e2e-tests` | Generate end-to-end tests | Test files |

### Review Skills

| Command | Use When | Output |
|---------|----------|--------|
| `bmm-retrospective` | Post-epic review | Lessons learned |
| `bmm-correct-course` | Manage significant changes | Course correction |

### BMad Agent Shortcuts

Direct agent invocation for specialized tasks.

| Agent | Use When | Command |
|-------|----------|---------|
| `/analyst` | Market research, project briefs, initial discovery | `/analyst` |
| `/architect` | System design, API design, infrastructure planning | `/architect` |
| `/dev` | Code implementation, debugging, refactoring | `/dev` |
| `/pm` | PRDs, product strategy, feature prioritization | `/pm` |
| `/po` | Backlog management, story refinement, prioritization | `/po` |
| `/qa` | Test planning, quality assurance, code improvements | `/qa` |
| `/sm` | Scrum master, retrospectives, sprint planning | `/sm` |
| `/ux-expert` | UI/UX design, wireframes, front-end specs | `/ux-expert` |
| `/tech-writer` | Documentation, guides, references | `/bmad-agent-bmm-tech-writer` |

### Party Mode

| Command | Use When | Behavior |
|---------|----------|----------|
| `party-mode` | Group discussions between all agents | Multi-agent conversation |

---

## BMad Tasks (Specialized Workflows)

### Planning Tasks

| Task | Use When | Command |
|------|----------|---------|
| Create brownfield epic | Document existing project epic | `/BMad:tasks:brownfield-create-epic` |
| Create brownfield story | Document existing project story | `/BMad:tasks:brownfield-create-story` |
| Create deep research prompt | Need comprehensive research | `/BMad:tasks:create-deep-research-prompt` |
| Create doc | Create documentation | `/BMad:tasks:create-doc` |
| Advanced elicitation | Deep requirements gathering | `/BMad:tasks:advanced-elicitation` |
| Trace requirements | Map requirements to implementation | `/BMad:tasks:trace-requirements` |

### Quality Tasks

| Task | Use When | Command |
|------|----------|---------|
| QA gate | Run quality checkpoint | `/BMad:tasks:qa-gate` |
| Test design | Design test strategy | `/BMad:tasks:test-design` |
| NFR assessment | Assess non-functional requirements | `/BMad:tasks:nfr-assess` |
| Risk profile | Assess project risks | `/BMad:tasks:risk-profile` |

### Execution Tasks

| Task | Use When | Command |
|------|----------|---------|
| Execute checklist | Run through checklist | `/BMad:tasks:execute-checklist` |
| Apply QA fixes | Apply fixes from QA review | `/BMad:tasks:apply-qa-fixes` |
| Correct course | Manage mid-sprint changes | `/BMad:tasks:correct-course` |

### Review Tasks

| Task | Use When | Command |
|------|----------|---------|
| Review story | Validate story before implementation | `/BMad:tasks:review-story` |
| Validate next story | Check story readiness | `/BMad:tasks:validate-next-story` |
| Create next story | Generate next story in backlog | `/BMad:tasks:create-next-story` |

### Utility Tasks

| Task | Use When | Command |
|------|----------|---------|
| Shard doc | Split large markdown documents | `/BMad:tasks:shard-doc` |
| Index docs | Create index.md for folder | `/BMad:tasks:index-docs` |
| Generate AI frontend prompt | Create frontend implementation prompt | `/BMad:tasks:generate-ai-frontend-prompt` |
| Facilitate brainstorming | Run brainstorming session | `/BMad:tasks:facilitate-brainstorming-session` |
| KB mode interaction | Knowledge base interaction | `/BMad:tasks:kb-mode-interaction` |

---

## Selection Decision Tree

```
START
  │
  ├─ Is this a new feature without a spec?
  │   YES → /superpowers:brainstorming OR /ralph-specum:start
  │   NO  ↓
  │
  ├─ Do you have a written plan?
  │   YES → /superpowers:executing-plans OR /gsd:execute-phase
  │   NO  ↓
  │
  ├─ Are tests failing?
  │   YES → /superpowers:systematic-debugging
  │   NO  ↓
  │
  ├─ Is work claimed complete but unverified?
  │   YES → /superpowers:verification-before-completion
  │   NO  ↓
  │
  ├─ Need to check what to do next?
  │   YES → /gsd:progress
  │   NO  ↓
  │
  ├─ Need to plan a phase?
  │   YES → /gsd:plan-phase
  │   NO  ↓
  │
  ├─ Need research before implementing?
  │   YES → /ralph-specum:research OR /bmad-bmm-technical-research
  │   NO  ↓
  │
  ├─ Need to create a story?
  │   YES → /bmad-bmm-create-story
  │   NO  ↓
  │
  ├─ Need to implement a story?
  │   YES → /bmad-bmm-dev
  │   NO  ↓
  │
  ├─ Need to generate tests?
  │   YES → /bmad-bmm-qa-generate-e2e-tests
  │   NO  ↓
  │
  └─ Default: Continue current task or check /gsd:progress
```

---

## Quick Reference by Scenario

### "I don't know what to do"
```
/gsd:progress
```

### "I need to implement something"
```
/superpowers:test-driven-development
# or if there's a spec:
/ralph-specum:implement
# or if there's a story:
/bmad-bmm-dev
```

### "Tests are failing"
```
/superpowers:systematic-debugging
# or:
/gsd:debug
```

### "I'm done, verify my work"
```
/superpowers:verification-before-completion
# or:
/gsd:verify-work
```

### "Need to design something new"
```
/superpowers:brainstorming
# or for formal spec:
/ralph-specum:start
```

### "Need to plan next phase"
```
/gsd:plan-phase <number>
```

### "Need to create a story"
```
/bmad-bmm-create-story
```

### "Need research"
```
/ralph-specum:research
# or:
/bmad-bmm-technical-research
```

### "Need architecture design"
```
/bmad-bmm-create-architecture
# or:
/architect
```

### "Need code review"
```
/superpowers:requesting-code-review
# or:
/bmad-bmm-code-review
```

### "Need to run tests"
```
pytest tests/
# Then verify with:
/superpowers:verification-before-completion
```

### "Session interrupted, need to resume"
```
/gsd:resume-work
```

### "Need to understand codebase"
```
/gsd:map-codebase
# or:
/ralph-specum:index
```

### "Need to add a new phase"
```
/gsd:add-phase
```

---

## Plugin Selection Heuristics by Task Type

| Task Type | Primary Plugin | Secondary Plugin | Why |
|-----------|----------------|------------------|-----|
| New feature design | `/superpowers:brainstorming` | `/ralph-specum:start` | Explores requirements first |
| Implementation | `/superpowers:test-driven-development` | `/ralph-specum:implement` | Enforces TDD |
| Debugging | `/superpowers:systematic-debugging` | `/gsd:debug` | Structured diagnosis |
| Planning | `/gsd:plan-phase` | `/bmad-bmm-create-architecture` | Phase-level breakdown |
| Research | `/ralph-specum:research` | `/bmad-bmm-technical-research` | Domain investigation |
| Quality | `/bmad-bmm-qa` | `/superpowers:verification-before-completion` | QA gates |
| Documentation | `/bmad-bmm-document-project` | `/BMad:tasks:index-docs` | Project docs |
| Story creation | `/bmad-bmm-create-story` | `/bmad-bmm-create-epics-and-stories` | Agile breakdown |

---

## Enforcement Levels Summary

| Level | Behavior | Examples |
|-------|----------|----------|
| **Hard Gate** | Blocks progress until satisfied | TDD deletes non-tested code, verification requires evidence |
| **Soft Gate** | Recommends but doesn't block | debugging workflow, code review |
| **Required** | Must be invoked before related work | brainstorming before features |
| **Optional** | Can be used when helpful | Most utility commands |

---

*Last updated: 2026-02-28*
*Version: 2.0*
