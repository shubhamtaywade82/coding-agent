# Coding Agent Architecture

## Overview

This coding agent is built on three layers:

```
coding-agent (this repo)
   ├─ tools (filesystem, lint, syntax)
   ├─ domain policies
   │
agent_runtime
   ├─ FSM
   ├─ loop control
   ├─ tool orchestration
   │
ollama-client
   ├─ generate (planner)
   ├─ chat (executor)
```

## Layer Responsibilities

### 1. `ollama-client` (LLM Communication)

**Responsible for:**
- `/generate` → planner calls
- `/chat` → executor calls
- Tool-call parsing
- Model abstraction

**Never:**
- Runs loops
- Executes tools
- Decides termination

**Used in:**
- `Agent::Planner` - calls `client.generate()`
- `Agent::Executor` - calls `client.chat()`

### 2. `agent_runtime` (FSM & Orchestration)

**Responsible for:**
- The FSM (finite state machine)
- Loop orchestration
- Tool dispatch
- Tool observation injection
- Termination / safety

**Owns:**
- `AgentRuntime::Runner#run` - main execution loop
- Tool execution via `AgentRuntime::ToolRunner`
- State management

**Used in:**
- `CodingAgent.run()` - wires everything together
- `Agent::Planner` - inherits from `AgentRuntime::Planner`
- `Agent::Executor` - inherits from `AgentRuntime::Executor`

### 3. `coding-agent` (Domain Logic)

**Responsible for:**
- Repository exploration tools
- File system operations
- Syntax validation
- Linting
- Safety policies

**Contains:**
- All tool implementations (pure Ruby)
- Domain-specific policies
- Safety boundaries

## Execution Flow

```
1. CodingAgent.run(task)
   ↓
2. Creates Ollama::Client
   ↓
3. Creates Agent::Planner (uses ollama-client)
   ↓
4. Creates Agent::Executor (uses ollama-client)
   ↓
5. AgentRuntime::Runner.new(...).run(task)
   ↓
6. Runtime orchestrates:
   - Planner runs once (via ollama-client /generate)
   - Executor loops (via ollama-client /chat)
   - Tools execute (via AgentRuntime::ToolRunner)
   - Syntax checks gate continuation
   - Termination enforced by policies
```

## Key Files

### Main Entry Point
- `lib/coding_agent.rb` - Wires ollama-client + agent_runtime

### Agent Components
- `lib/agent/planner.rb` - Inherits `AgentRuntime::Planner`, uses `ollama-client`
- `lib/agent/executor.rb` - Inherits `AgentRuntime::Executor`, uses `ollama-client`
- `lib/agent/policies.rb` - Safety policies and limits

### Tools
- `lib/tools/` - All tool implementations (pure Ruby, no LLM calls)

### Utilities
- `lib/utils/` - File hashing, git operations, language detection

## Why This Architecture?

**Separation of Concerns:**
- `ollama-client` = LLM communication only
- `agent_runtime` = execution control only
- `coding-agent` = domain logic only

**Benefits:**
- Testable (each layer can be mocked)
- Composable (swap LLM providers, runtimes)
- Safe (tools are pure Ruby, no prompt injection)
- Deterministic (FSM controls flow, not prompts)

## Dependencies

```ruby
# In coding-agent.gemspec
spec.add_dependency "agent_runtime", "~> 0.1"
spec.add_dependency "ollama-client", "~> 0.1"
```

Both are **mandatory** - the agent cannot function without either.
