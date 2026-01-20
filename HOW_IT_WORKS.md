# How Coding Agent Works

This document explains the internal execution flow of the coding agent, using a concrete example.

## Overview

The coding agent is a **tool-using LLM system** that:
- Uses an LLM (via Ollama) as a **planner and executor**
- Executes **pure Ruby tools** for actual file operations
- Enforces **safety policies** to prevent errors and loops
- Validates **syntax and correctness** after every edit

## Architecture Layers

```
┌─────────────────────────────────────┐
│   coding-agent (this repo)          │
│   ├─ Tools (read_file, apply_patch) │
│   ├─ Policies (safety rules)        │
│   └─ Domain logic                   │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│   agent_runtime                      │
│   ├─ FSM (state machine)             │
│   ├─ Loop orchestration              │
│   └─ Tool dispatch                   │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│   ollama-client                      │
│   ├─ /generate (planner)            │
│   └─ /chat (executor)               │
└─────────────────────────────────────┘
```

## Execution Flow

### Phase 1: Initialization

When you call `CodingAgent.run("create Calculator class")`:

1. **Creates Ollama Client**
   ```ruby
   ollama = Ollama::Client.new  # Connects to local LLM server
   ```

2. **Creates Planner**
   ```ruby
   planner = Agent::Planner.new(client: ollama, model: "qwen2.5-coder")
   # Planner uses LLM /generate endpoint to decide first tool
   ```

3. **Creates Executor**
   ```ruby
   executor = Agent::Executor.new(tool_registry: tool_registry)
   # Executor uses LLM /chat endpoint in a loop
   ```

4. **Creates Policy**
   ```ruby
   policy = Agent::Policy.new
   # Validates decisions, prevents loops, blocks dangerous actions
   ```

5. **Registers Tools**
   ```ruby
   # All tools in lib/tools/ are registered
   # Tools are pure Ruby classes with a .call() method
   ```

### Phase 2: The Main Loop

The agent runs in a loop (max 25 iterations):

```
┌─────────────────────────────────────────────┐
│  AgentRuntime::Agent.run(initial_input)    │
│  (Main Loop Controller)                     │
└──────────────────┬──────────────────────────┘
                   │
                   ▼
        ┌──────────────────────┐
        │  Is first iteration? │
        └──────┬───────────────┘
               │
        ┌──────▼──────┐      ┌──────────────┐
        │   YES       │      │     NO        │
        │             │      │              │
        │ Use Planner │      │ Use Executor │
        │ (/generate) │      │ (/chat)      │
        └──────┬──────┘      └──────┬───────┘
               │                    │
               └──────────┬─────────┘
                          │
                          ▼
        ┌─────────────────────────────┐
        │  LLM returns JSON decision:  │
        │  {                            │
        │    action: "read_file",       │
        │    params: {path: "..."},    │
        │    confidence: 0.9           │
        │  }                            │
        └──────────────┬────────────────┘
                       │
                       ▼
        ┌─────────────────────────────┐
        │  Policy validates decision  │
        │  ✓ Is action allowed?       │
        │  ✓ Not a dangerous action?  │
        │  ✓ Not a repeated call?    │
        └──────────────┬────────────────┘
                       │
                       ▼
        ┌─────────────────────────────┐
        │  Tool executes (Pure Ruby)  │
        │  Tools::Repo::ReadFile.call │
        │  → Reads file from disk     │
        │  → Returns: {content: "...",│
        │              sha256: "..."} │
        └──────────────┬────────────────┘
                       │
                       ▼
        ┌─────────────────────────────┐
        │  Tool result added to state │
        │  (Available to next LLM call)│
        └──────────────┬────────────────┘
                       │
                       ▼
        ┌─────────────────────────────┐
        │  Check: Task complete?      │
        │  - Syntax valid?             │
        │  - Max iterations?          │
        │  - Error occurred?          │
        └──────────────┬────────────────┘
                       │
        ┌──────────────▼───────────────┐
        │  Continue loop?              │
        └──────┬───────────────────────┘
               │
        ┌──────▼──────┐      ┌──────────┐
        │    YES      │      │    NO    │
        │             │      │          │
        │  Loop back  │      │   Stop   │
        │  to Executor│      │          │
        └─────────────┘      └──────────┘
```

## Concrete Example: "Create Calculator Class"

Let's trace through a complete execution:

### Task
```
"create or update a Calculator class and use OOPs in ruby"
```

### Iteration 1: First Decision (Planner)

**Input to LLM:**
```
You are a coding task planner.

Rules:
- CRITICAL: If task mentions "Calculator", IMMEDIATELY call read_file with path "calculator.rb"
- ...

Task: create or update a Calculator class and use OOPs in ruby

Output a JSON decision with:
- action: The tool to use
- params: Parameters for the tool
- confidence: Your confidence (0.0 to 1.0)
```

**LLM Response:**
```json
{
  "action": "read_file",
  "params": {"path": "calculator.rb"},
  "confidence": 0.8
}
```

**What Happens:**
1. Policy validates: ✅ Action allowed, not dangerous, first call
2. Tool executes: `Tools::Repo::ReadFile.call({"path" => "calculator.rb"})`
3. Tool reads: `playground/calculator.rb` (file exists but is empty)
4. Tool returns:
   ```ruby
   {
     path: "/home/.../playground/calculator.rb",
     content: "",
     sha256: "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
     lines: 1
   }
   ```

### Iteration 2: Second Decision (Executor)

**Input to LLM:**
```
You are a coding task executor.

Previous tool results:
- read_file: {content: "", sha256: "...", lines: 1}

Task: create or update a Calculator class and use OOPs in ruby

Rules:
- If file is empty, use apply_patch to add full class implementation
- apply_patch requires: path, edits array with start_line, end_line, replacement
- ...

What tool should I call next?
```

**LLM Response:**
```json
{
  "action": "apply_patch",
  "params": {
    "path": "calculator.rb",
    "edits": [{
      "start_line": 1,
      "end_line": 1,
      "replacement": "class Calculator\n  def initialize\n    @result = 0\n  end\n\n  def add(num)\n    @result += num\n  end\n\n  def subtract(num)\n    @result -= num\n  end\nend\n"
    }]
  },
  "confidence": 0.9
}
```

**What Happens:**
1. Policy validates: ✅ Action allowed, not a repeat
2. Tool validates edits format: ✅ Array with valid hash
3. Tool executes: `Tools::FS::ApplyPatch.call(...)`
4. Tool applies patch:
   - Reads current file content
   - Replaces line 1 with new Calculator class code
   - Writes file back
5. Tool returns: `{status: "patched"}`

**File Now Contains:**
```ruby
class Calculator
  def initialize
    @result = 0
  end

  def add(num)
    @result += num
  end

  def subtract(num)
    @result -= num
  end
end
```

### Iteration 3: Third Decision (Executor)

**Input to LLM:**
```
Previous tool results:
- apply_patch: {status: "patched"}

Task: create or update a Calculator class and use OOPs in ruby

Rules:
- After editing a file, validate syntax ONCE
- ...

What tool should I call next?
```

**LLM Response:**
```json
{
  "action": "ruby_syntax_check",
  "params": {"path": "calculator.rb"},
  "confidence": 1.0
}
```

**What Happens:**
1. Policy validates: ✅ Action allowed
2. Tool executes: `Tools::Validation::RubySyntaxCheck.call(...)`
3. Tool runs: `ruby -c playground/calculator.rb`
4. Tool returns: `{ok: true}` (syntax is valid)

### Iteration 4: Fourth Decision (Executor)

**Input to LLM:**
```
Previous tool results:
- ruby_syntax_check: {ok: true}

Task: create or update a Calculator class and use OOPs in ruby

Rules:
- If syntax check passes (ok: true), task is complete - STOP
- ...

What tool should I call next?
```

**LLM Response:**
```json
{
  "action": "stop",
  "params": {},
  "confidence": 1.0
}
```

**What Happens:**
1. Agent detects completion condition
2. Loop exits
3. Returns success

## Key Components Explained

### 1. Planner (One-Shot)

**Purpose:** Decides the first tool to call

**How it works:**
- Uses LLM `/generate` endpoint (single-shot, no conversation)
- Receives task description + rules + available tools
- Returns JSON decision: `{action, params, confidence}`

**Example:**
```ruby
planner = Agent::Planner.new(client: ollama, model: "qwen2.5-coder")
decision = planner.plan(input: "create Calculator class", state: nil)
# => {action: "read_file", params: {...}, confidence: 0.8}
```

### 2. Executor (Loop)

**Purpose:** Decides subsequent tools based on previous results

**How it works:**
- Uses LLM `/chat` endpoint (conversational, maintains context)
- Receives:
  - Task description
  - Previous tool results (as observations)
  - Current state
- Returns next tool decision

**Example:**
```ruby
executor = Agent::Executor.new(tool_registry: registry)
decision = executor.execute(
  messages: [
    {role: "user", content: "Task: create Calculator"},
    {role: "assistant", content: "I'll read the file first"},
    {role: "tool", content: "read_file result: {content: ''}"}
  ]
)
# => {action: "apply_patch", params: {...}}
```

### 3. Tools (Pure Ruby)

**Purpose:** Perform actual file operations

**Characteristics:**
- No LLM calls (deterministic)
- Pure Ruby classes
- Must implement `.call(args, state:)` method
- Return hash with results

**Example Tool:**
```ruby
module Tools
  module FS
    class ApplyPatch < Tools::Base
      def self.name
        "apply_patch"
      end

      def self.call(args, _state:)
        path = args.fetch("path")
        edits = args.fetch("edits")
        # ... validate, apply edits, write file ...
        {status: "patched"}
      end
    end
  end
end
```

### 4. Policy (Safety)

**Purpose:** Validate decisions and prevent errors

**Checks:**
- Is action allowed?
- Is it a dangerous action? (delete_file, etc.)
- Is it a repeated call? (anti-loop protection)
- Are parameters valid?

**Example:**
```ruby
policy = Agent::Policy.new
policy.validate!(decision, state: state)
# Raises PolicyViolation if invalid
```

## Safety Mechanisms

### 1. Patch-Based Edits Only

**Why:** Prevents accidental full-file corruption

**How:**
- `apply_patch` only modifies specific line ranges
- Validates file hash before editing (optional)
- Never allows full-file rewrites

### 2. Syntax Validation

**Why:** Ensures code is syntactically correct

**How:**
- Runs `ruby -c` after every edit
- Blocks continuation if syntax invalid
- Agent must fix errors before proceeding

### 3. Loop Prevention

**Why:** Prevents infinite loops

**How:**
- Policy tracks recent calls
- Blocks repeated identical calls
- Max 25 iterations per task

### 4. Path Restrictions

**Why:** Prevents modifying files outside playground

**How:**
- All paths normalized to playground directory
- Validates path is within playground before operations
- Rejects absolute paths outside playground

## Tool Execution Flow

```
LLM Decision
    │
    ▼
Policy Validation
    │
    ▼
Tool Registry Lookup
    │
    ▼
Tool.call(args, state)
    │
    ▼
Tool Implementation
    │
    ├─ Validate inputs
    ├─ Perform operation (read/write file, etc.)
    └─ Return result
    │
    ▼
Result Added to State
    │
    ▼
Available to Next LLM Call
```

## State Management

The agent maintains state across iterations:

```ruby
state = AgentRuntime::State.new
# Tracks:
# - steps: iteration count
# - observations: tool results
# - history: previous decisions
```

Each tool result becomes an "observation" available to the next LLM call.

## Error Handling

### Tool Errors

If a tool raises an error:
1. Error is caught by executor
2. Error message added to state as observation
3. LLM sees error in next iteration
4. LLM can decide to retry or fix the issue

### Policy Violations

If policy blocks a decision:
1. `PolicyViolation` exception raised
2. Agent stops execution
3. Error message shown to user

### Syntax Errors

If syntax check fails:
1. Error details returned: `{ok: false, error: "..."}`
2. Error added to state
3. LLM sees error, decides to fix with `apply_patch`
4. Process repeats until syntax valid

## Example: Complete Execution Trace

```
[STEP] Action: read_file
       Params: {"path"=>"calculator.rb"}
       Result: {content: "", sha256: "...", lines: 1}

[STEP] Action: apply_patch
       Params: {"path"=>"calculator.rb", "edits"=>[...]}
       Result: {status: "patched"}

[STEP] Action: ruby_syntax_check
       Params: {"path"=>"calculator.rb"}
       Result: {ok: true}

✅ Agent completed successfully
```

## Why This Architecture?

### Safety
- Tools are pure Ruby (no prompt injection)
- Policy can block dangerous actions
- Path restrictions prevent file system access

### Determinism
- File operations are predictable
- No randomness in tool execution
- Reproducible results

### Control
- Policy enforces rules
- Max iterations prevent infinite loops
- Syntax validation ensures correctness

### Feedback
- LLM sees actual tool results
- Can adapt based on real file contents
- Error messages guide fixes

## Comparison to Other Approaches

### ❌ Bad: Direct Code Generation
```
LLM → Generates full file → Write file
```
**Problems:**
- No validation
- Can corrupt existing files
- No feedback loop

### ✅ Good: Tool-Based (This Agent)
```
LLM → Decides tool → Tool executes → LLM sees result → Decides next tool
```
**Benefits:**
- Validated operations
- Safe file modifications
- Adaptive based on results

## Summary

The coding agent works by:

1. **LLM as Planner/Executor**: Decides which tools to call
2. **Pure Ruby Tools**: Perform actual file operations
3. **Policy Validation**: Ensures safety and prevents errors
4. **Iterative Loop**: Adapts based on tool results
5. **Validation**: Checks syntax and correctness

This architecture provides a **safe, controlled, and deterministic** way to automate code modifications while leveraging LLM intelligence for planning and decision-making.
