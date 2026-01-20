# Usage Guide

## Prerequisites

Before using `coding-agent`, ensure you have:

1. **Ollama installed and running**
   ```bash
   # Install Ollama (if not already installed)
   curl -fsSL https://ollama.com/install.sh | sh

   # Start Ollama service
   ollama serve

   # Pull the model (in another terminal)
   ollama pull qwen2.5-coder
   ```

2. **Required gems installed**
   - `ollama-client` - for LLM communication
   - `agent_runtime` - for FSM and loop orchestration
   - `coding-agent` - this gem

3. **Ruby 3.0+**

---

## Installation

### As a Gem

Add to your `Gemfile`:

```ruby
gem "coding-agent"
```

Then run:

```bash
bundle install
```

### From Source

```bash
git clone <repository-url>
cd coding-agent
bundle install
bundle exec rake install
```

---

## Usage

### Command Line Interface (CLI)

The simplest way to use the agent:

```bash
# Basic usage
bin/agent "Add a User model with email validation"

# Or if installed as a gem
coding-agent "Refactor the authentication service"
```

**Example:**

```bash
cd /path/to/your/project
bin/agent "Add a method to calculate total price in the Order class"
```

The agent will:
1. Explore your repository
2. Read relevant files
3. Propose patch-based edits
4. Validate syntax after each edit
5. Show you a diff preview
6. Complete the task

---

### Programmatic Usage

#### Basic Example

```ruby
require "coding_agent"

# Simple usage with default model
CodingAgent.run("Add error handling to the payment processor")
```

#### Custom Model

```ruby
require "coding_agent"

# Use a different model
CodingAgent.run(
  "Refactor the API client",
  model: "llama3.2"
)
```

#### Custom Client

```ruby
require "coding_agent"
require "ollama/client"

# Create a custom Ollama client
client = Ollama::Client.new(
  model: "qwen2.5-coder",
  base_url: "http://localhost:11434"
)

# Use the custom client
CodingAgent.run("Add logging to all API calls", client: client)
```

#### Access Available Tools

```ruby
require "coding_agent"

# See all available tools
puts CodingAgent.tools.map(&:name)
# => ["list_files", "read_file", "search", "create_file", "apply_patch", ...]
```

---

## How It Works

### Execution Flow

```
1. You provide a task
   ↓
2. Planner generates a plan (single-shot, /generate)
   ↓
3. Executor loops (chat-based, /chat)
   ↓
4. Tools execute (pure Ruby, no LLM)
   ↓
5. Syntax validation after edits
   ↓
6. Lint checking
   ↓
7. Diff preview
   ↓
8. Task complete or retry
```

### Safety Features

- **Patch-based edits only** - Never rewrites entire files
- **Hash validation** - Files must match expected state before editing
- **Syntax checking** - Validates after every edit
- **Step limits** - Maximum 25 steps per task (configurable)
- **Diff preview** - See changes before finalizing

---

## Examples

### Example 1: Add a Method

```bash
bin/agent "Add a calculate_total method to the ShoppingCart class"
```

The agent will:
1. Search for `ShoppingCart` class
2. Read the file
3. Apply a patch to add the method
4. Validate Ruby syntax
5. Show you the diff

### Example 2: Refactor Code

```bash
bin/agent "Extract the email validation logic into a separate method"
```

### Example 3: Fix Issues

```bash
bin/agent "Fix all RuboCop offenses in app/models/user.rb"
```

---

## Configuration

### Policies

Edit `lib/agent/policies.rb` to customize:

```ruby
module Agent
  module Policies
    MAX_STEPS = 25  # Maximum steps per task

    def self.allow_continue?(state)
      state.steps < MAX_STEPS
    end

    def self.allow_tool?(_tool_name)
      true  # Allow all tools by default
    end
  end
end
```

### Model Selection

Default model is `qwen2.5-coder`. Change it:

```ruby
# In bin/agent or your code
CodingAgent.run(task, model: "llama3.2")
```

---

## Available Tools

The agent has access to these tools:

### Repository Exploration (Read-Only)
- `list_files` - List files with glob patterns
- `read_file` - Read file content with hash
- `search` - Search for text in files

### File System
- `create_file` - Create new files (fails if exists)
- `apply_patch` - Apply line-based patches
- `diff_preview` - Show git diff
- `revert_last_change` - Revert uncommitted changes

### Validation
- `ruby_syntax_check` - Validate Ruby syntax

### Linting
- `rubocop_check` - Check Ruby code style

### Errors
- `collect_errors` - Collect validation/lint errors

---

## Troubleshooting

### "Ollama connection failed"

Ensure Ollama is running:
```bash
ollama serve
```

Check if the model is available:
```bash
ollama list
```

### "File changed since read"

This happens when:
- The file was modified externally
- Multiple edits conflict

**Solution:** The agent will retry or you can revert and start fresh.

### "Syntax error after edit"

The agent will:
1. Detect the syntax error
2. Attempt to fix it
3. Re-validate
4. Continue or stop based on policies

### "Maximum steps reached"

The agent hit the step limit (default: 25).

**Solution:** Increase `MAX_STEPS` in policies or break the task into smaller pieces.

---

## Best Practices

1. **Be specific** - Clear tasks work better
   ```bash
   # Good
   bin/agent "Add email validation to User model"

   # Less clear
   bin/agent "Fix the user thing"
   ```

2. **Start small** - Break large tasks into smaller ones
   ```bash
   # Better: Multiple focused tasks
   bin/agent "Add User model"
   bin/agent "Add email validation to User"
   bin/agent "Add tests for User validation"
   ```

3. **Review diffs** - Always check `diff_preview` before finalizing

4. **Use git** - Commit before running the agent for easy rollback

5. **Test after** - Run your test suite after agent completes

---

## Integration Examples

### Rake Task

```ruby
# Rakefile
require "coding_agent"

desc "Run coding agent on a task"
task :agent, [:task] do |_t, args|
  abort("Usage: rake agent['your task']") if args[:task].nil?
  CodingAgent.run(args[:task])
end
```

Usage:
```bash
rake agent["Add a helper method"]
```

### Rails Console

```ruby
# rails console
require "coding_agent"

CodingAgent.run("Add a scope to find active users")
```

### Script

```ruby
#!/usr/bin/env ruby
# refactor.rb
require "coding_agent"

task = ARGV[0] || "Refactor the payment service"
CodingAgent.run(task, model: "qwen2.5-coder")
```

---

## Advanced Usage

### Custom Tool Execution

```ruby
require "coding_agent"

# Access tools directly (for testing/debugging)
tool = Tools::Repo::ReadFile
result = tool.call({ "path" => "app/models/user.rb" }, state: nil)
puts result[:content]
```

### Monitoring Execution

```ruby
require "coding_agent"

# The runtime handles execution
# You can add logging in the tools or policies
```

---

## Next Steps

- Read [ARCHITECTURE.md](ARCHITECTURE.md) for technical details
- Check [README.md](README.md) for overview
- Review tool implementations in `lib/tools/`
- Customize policies in `lib/agent/policies.rb`
