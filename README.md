# Coding::Agent

> **A controlled code-modification agent with read-only exploration, patch-based edits, and compiler/linter-verified correctness.**

This is **not** "an AI that codes". This is a **production-grade coding agent** with strict safety boundaries, deterministic execution, and tool-based code modification.

---

## What This Is

A **file-system automation agent with an LLM as a planner** — not a text generator.

### Key Principles

* ✅ **Read-only exploration** before any modifications
* ✅ **Patch-based edits only** — never full-file rewrites
* ✅ **Syntax validation** after every edit
* ✅ **Linter verification** before finalization
* ✅ **Deterministic execution** with safety controls
* ✅ **Tool-based architecture** — not prompt magic

---

## Architecture Overview

### Agent Runtime Responsibilities

The agent runtime handles:

* Intent → plan → loop → stop
* Tool calling discipline
* Preventing uncontrolled edits
* Preventing infinite loops
* Keeping execution deterministic

### Tool Layer Responsibilities

The tool layer provides controlled, safe operations:

---

## Required Toolset

### 1️⃣ Repository Exploration Tools (READ-ONLY)

These tools **never modify code**.

#### `list_files`

```ruby
list_files(path: ".", glob: "**/*.{rb,js,ts,py}")
```

* Explores repo structure
* Supports globbing
* Excludes `.git`, `node_modules`, `vendor`, etc.

#### `read_file`

```ruby
read_file(path: "app/models/user.rb")
```

* Returns full file content
* Includes line numbers

#### `search`

```ruby
search(query: "UserMailer", path: ".")
```

* Ripgrep or equivalent
* Returns file + line numbers

🚫 **No write operations allowed here**

---

### 2️⃣ Code Understanding / Context Tools (OPTIONAL)

These tools help **reduce hallucinations**.

#### `get_language`

```ruby
get_language(path: "app/models/user.rb") # => ruby
```

#### `get_project_metadata`

```ruby
get_project_metadata
# => { type: "rails", ruby_version: "3.2", framework: "rails" }
```

Prevents:
* Wrong syntax
* Wrong conventions
* Wrong linters

---

### 3️⃣ File Creation Tools (STRICT)

File creation must be **explicit and gated**.

#### `create_file`

```ruby
create_file(
  path: "app/services/foo_service.rb",
  content: "class FooService\nend\n"
)
```

Rules:
* Fail if file exists
* Never overwrite
* No directory traversal
* Path must be under project root

---

### 4️⃣ Patch-Based Editing Tools (CRITICAL)

🚨 **Never allow "rewrite entire file" edits**

#### `apply_patch`

```ruby
apply_patch(
  path: "app/models/user.rb",
  edits: [
    {
      start_line: 14,
      end_line: 18,
      replacement: "validates :email, presence: true\n"
    }
  ]
)
```

Rules:
* Line-range based
* Validate file hash before applying
* Reject if file changed since read
* Apply atomically

This prevents:
* Accidental deletions
* Prompt drift corruption
* Multi-file chaos

---

### 5️⃣ Syntax Validation Tools (MANDATORY)

The agent must **never assume correctness**.

#### Ruby

```ruby
ruby_syntax_check(path)
# ruby -c
```

#### JS / TS

```ruby
eslint_check(path)
```

#### Python

```ruby
python_syntax_check(path)
```

Rules:
* Must run after every edit
* Must fail fast
* Must return structured errors (line, column, message)

---

### 6️⃣ Linting & Formatting Tools (OPTIONAL but expected)

These are **not fixes**, they are **feedback loops**.

#### Ruby

```ruby
rubocop_check(path)
rubocop_autocorrect(path) # OPTIONAL, dangerous
```

#### JS

```ruby
eslint_check
prettier_format
```

Rules:
* Lint first
* Fix only if explicitly requested
* Never auto-fix silently

---

### 7️⃣ Error Feedback Tool (READ-ONLY INPUT TO AGENT)

After syntax/lint failure:

#### `collect_errors`

```ruby
collect_errors
# => [{ file, line, column, message }]
```

This is fed back into the agent as **tool observation**, not prompt text.

---

### 8️⃣ Safety & Control Tools (NON-NEGOTIABLE)

#### `diff_preview`

```ruby
diff_preview
```

* Shows what changed
* Used before final confirmation

#### `revert_last_change`

```ruby
revert_last_change
```

These prevent:
* Accidental corruption
* Broken working trees

---

## The Agent Loop

```
PLAN (generate)
  ↓
EXECUTE (chat)
  ↓
READ tools
  ↓
PATCH tool
  ↓
SYNTAX CHECK
  ↓
LINT CHECK
  ↓
IF errors → loop
  ↓
FINALIZE
```

### What the Agent NEVER Does

* ❌ Writes raw files
* ❌ Guesses syntax
* ❌ Applies multiple edits blindly
* ❌ Decides correctness without verification

### What the Agent ALWAYS Does

1. Explores
2. Reads
3. Proposes patch
4. Applies patch
5. Validates syntax
6. Validates lint
7. Stops or fixes again

---

## Minimum Viable Toolset

| Category         | Required |
| ---------------- | -------- |
| Repo exploration | ✅        |
| File read        | ✅        |
| Search           | ✅        |
| Patch-based edit | ✅        |
| Syntax check     | ✅        |
| Lint feedback    | ⚠️        |
| Diff preview     | ✅        |
| Revert           | ✅        |

Everything else is optional.

---

## What Most People Get Wrong

❌ Allow full-file rewrites
❌ Let model "fix lint" without tools
❌ Apply edits before syntax validation
❌ Let the model decide "looks fine"
❌ Let chat output directly write files

**Coding::Agent avoids these mistakes.**

---

## Installation

Add this line to your application's Gemfile:

```ruby
gem "coding-agent"
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install coding-agent
```

**Prerequisites:**
- Ollama installed and running (`ollama serve`)
- Model pulled (`ollama pull qwen2.5-coder`)
- Ruby 3.0+

---

## Quick Start

### Command Line

```bash
# Navigate to your project
cd /path/to/your/project

# Run the agent
bin/agent "Add a User model with email validation"
```

### Programmatic

```ruby
require "coding_agent"

CodingAgent.run("Refactor the authentication service")
```

**See [USAGE.md](USAGE.md) for detailed usage guide.**

---

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

---

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/shubhamtaywade/coding-agent. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/shubhamtaywade/coding-agent/blob/master/CODE_OF_CONDUCT.md).

---

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

---

## Code of Conduct

Everyone interacting in the Coding::Agent project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/shubhamtaywade/coding-agent/blob/master/CODE_OF_CONDUCT.md).
