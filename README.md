# girb (Generative IRB)

An AI assistant for Ruby development. Works with IRB, Rails console, and the debug gem.

[日本語版 README](README_ja.md)

## Features

- **Context Awareness**: Understands local variables, instance variables, and runtime state
- **Tool Execution**: AI autonomously executes code, inspects objects, and reads files
- **Autonomous Investigation**: AI loops through investigate-execute-analyze cycles
- **Multi-environment Support**: Works with IRB, Rails console, and debug gem (rdbg)
- **Provider Agnostic**: Use any LLM (OpenAI, Anthropic, Gemini, Ollama, etc.)

## Quick Start

```bash
# 1. Install
gem install girb girb-ruby_llm

# 2. Set your API key
export GEMINI_API_KEY="your-api-key"  # or OPENAI_API_KEY, ANTHROPIC_API_KEY

# 3. Create ~/.girbrc
```ruby
require 'girb-ruby_llm'
Girb.configure do |c|
  c.provider = Girb::Providers::RubyLlm.new(model: 'gemini-2.5-flash')
end
```

# 4. Run
girb
```

Then type a question and press **Ctrl+Space**, or use `qq <question>`.

## Table of Contents

1. [Configuration](#1-configuration) - Common setup for all environments
2. [Ruby Scripts (IRB)](#2-ruby-scripts-irb) - Using with pure Ruby
3. [Rails](#3-rails) - Using with Rails console
4. [Debug Gem (rdbg)](#4-debug-gem-rdbg) - Step-through debugging with AI

---

## 1. Configuration

### Installation

```bash
gem install girb girb-ruby_llm
```

Available provider gems:
- [girb-ruby_llm](https://github.com/rira100000000/girb-ruby_llm) - OpenAI, Anthropic, Gemini, Ollama, etc. (Recommended)
- [girb-gemini](https://github.com/rira100000000/girb-gemini) - Google Gemini only

### API Keys

Set the API key for your chosen LLM provider as an environment variable:

```bash
export GEMINI_API_KEY="your-api-key"
# or OPENAI_API_KEY, ANTHROPIC_API_KEY, etc.
```

For detailed setup instructions (Ollama, other providers, advanced options), see the provider gem documentation:
- [girb-ruby_llm](https://github.com/rira100000000/girb-ruby_llm)
- [girb-gemini](https://github.com/rira100000000/girb-gemini)

### Create .girbrc

Create a `.girbrc` file in your project root (or home directory for global config):

```ruby
# .girbrc
require 'girb-ruby_llm'

Girb.configure do |c|
  c.provider = Girb::Providers::RubyLlm.new(model: 'gemini-2.5-flash')
end
```

girb searches for `.girbrc` in this order:
1. Current directory → parent directories (up to root)
2. `~/.girbrc` as fallback

### Model Examples

```ruby
# Google Gemini
c.provider = Girb::Providers::RubyLlm.new(model: 'gemini-2.5-flash')

# OpenAI
c.provider = Girb::Providers::RubyLlm.new(model: 'gpt-5.2-2025-12-11')

# Anthropic
c.provider = Girb::Providers::RubyLlm.new(model: 'claude-opus-4-5')
```

### Configuration Options

```ruby
Girb.configure do |c|
  # Required: LLM provider
  c.provider = Girb::Providers::RubyLlm.new(model: 'gemini-2.5-flash')

  # Optional: Debug output
  c.debug = true

  # Optional: Custom system prompt
  c.custom_prompt = <<~PROMPT
    This is production. Always confirm before destructive operations.
  PROMPT
end
```

### Environment Variables (Fallback)

Used when provider is not configured in `.girbrc`:

| Variable | Description |
|----------|-------------|
| `GIRB_PROVIDER` | Provider gem (e.g., `girb-ruby_llm`) |
| `GIRB_MODEL` | Model name (e.g., `gemini-2.5-flash`) |
| `GIRB_DEBUG` | Set to `1` for debug output |

### Session Persistence (Optional)

Persist AI conversation history across sessions. Only enabled when you explicitly set a session ID.

#### Enable

Set a session ID in `.girbrc`:

```ruby
Girb.configure do |c|
  c.provider = Girb::Providers::RubyLlm.new(model: 'gemini-2.5-flash')
end

# Enable session persistence (optional)
Girb.debug_session = "my-project"
```

Or set dynamically in code:

```ruby
Girb.debug_session = "debug-user-auth"
debugger  # Conversations in this session will be saved
```

#### Session Management Commands

Use in IRB or debug mode:

```
qq session status  # Show current session status
qq session list    # List saved sessions
qq session clear   # Clear current session
```

#### Behavior

- Sessions are saved to `.girb/sessions/<session_id>.json`
- Sessions inactive for 7+ days are automatically deleted
- Resuming with the same session ID continues the previous conversation
- Use `get_session_history` tool to reference past conversations

---

## 2. Ruby Scripts (IRB)

### Usage

Use `girb` command instead of `irb`:

```bash
girb
```

Or insert `binding.girb` in your code:

```ruby
def problematic_method
  result = some_calculation
  binding.girb  # AI-powered IRB starts here
  result
end
```

### How to Ask AI

**Ctrl+Space**: Press after typing your question

```
irb(main):001> Why did this fail?[Ctrl+Space]
```

**qq command**: Use the qq method

```
irb(main):001> qq How do I use this method?
```

### Available Tools (IRB)

| Tool | Description |
|------|-------------|
| `evaluate_code` | Execute Ruby code |
| `inspect_object` | Inspect object details |
| `get_source` | Get method/class source code |
| `list_methods` | List methods of an object |
| `find_file` | Search for files |
| `read_file` | Read file contents |
| `get_session_history` | Get IRB session history |
| `continue_analysis` | Request context refresh for autonomous investigation |

### Example

```
irb(main):001> x = [1, 2, 3]
irb(main):002> What methods can I use to find the sum?[Ctrl+Space]
You can use `x.sum` which returns 6. Alternatively, `x.reduce(:+)` or `x.inject(0, :+)`.
```

---

## 3. Rails

### Installation

Add to your Gemfile:

```ruby
group :development do
  gem 'girb'
  gem 'girb-ruby_llm'
end
```

```bash
bundle install
```

### Configuration

Create `.girbrc` in your Rails project root. See [Configuration](#1-configuration) for details.

### Usage

Just run `rails console` - girb loads automatically via Railtie:

```bash
rails console
```

### Additional Tools (Rails)

| Tool | Description |
|------|-------------|
| `query_model` | Execute ActiveRecord queries |
| `model_info` | Get model schema information |

### Example

```
irb(main):001> user = User.find(1)
irb(main):002> user.update(name: "test")
=> false
irb(main):003> Why did the update fail?[Ctrl+Space]
Checking `user.errors.full_messages` shows:
- "Email can't be blank"
The email attribute is being cleared during the update.
```

---

## 4. Debug Gem (rdbg)

Step-through debugging with AI assistance.

### Configuration

Same `.girbrc` as above.

### For Standalone Ruby Scripts

Add `require "debug"` and `require "girb"`, then use `debugger` statement:

**Note:** `require "debug"` must come before `require "girb"`.

```ruby
require "debug"
require "girb"

def calculate(x)
  result = x * 2
  debugger  # Stops here with AI assistance
  result + 1
end

calculate(5)
```

Run with ruby:

```bash
ruby your_script.rb
```

### For Rails

Create an initializer to load girb after debug gem:

```ruby
# config/initializers/girb.rb
require "girb" if Rails.env.development? || Rails.env.test?
```

Then use `debugger` statement in your code:

```ruby
def show
  @user = User.find(params[:id])
  debugger  # Stops here with AI assistance
end
```

### How to Ask AI (Debug Mode)

- **`qq <question>`** - Ask AI a question
- **Ctrl+Space** - Send current input to AI
- **Natural language** - Non-ASCII input (e.g., Japanese) automatically routes to AI

```
(rdbg) qq What is the value of result here?
(rdbg) 次の行に進んで[Ctrl+Space]
```

### AI Can Execute Debug Commands

The AI can run debugger commands for you:

```
(rdbg) qq Step through this loop and tell me when x becomes 1
```

The AI will use `step`, `next`, `continue`, `break`, etc. automatically.

### Ctrl+C to Interrupt

Press Ctrl+C to interrupt long-running AI operations. The AI will summarize progress.

### Available Tools (Debug Mode)

| Tool | Description |
|------|-------------|
| `evaluate_code` | Execute Ruby code in current context |
| `inspect_object` | Inspect object details |
| `get_source` | Get method/class source code |
| `read_file` | Read source files |
| `run_debug_command` | Execute debugger commands |
| `get_session_history` | Get debug session history |

### Example: Variable Tracking

```
(rdbg) qq Track all values of x through this loop and report when done

[AI sets breakpoints, runs continue, collects values]

Tracked values of x: [7, 66, 85, 11, 53, 42, 99, 23]
Loop completed.
```

---

## Custom Providers

Implement your own LLM provider:

```ruby
class MyProvider < Girb::Providers::Base
  def initialize(api_key:)
    @api_key = api_key
  end

  def chat(messages:, system_prompt:, tools:, binding: nil)
    # Call your LLM API
    response = call_my_llm(messages, system_prompt, tools)

    Girb::Providers::Base::Response.new(
      text: response.text,
      function_calls: response.tool_calls&.map { |tc| { name: tc.name, args: tc.args } }
    )
  end
end
```

---

## Requirements

- Ruby 3.2.0+
- IRB 1.6.0+ (for IRB/Rails usage)
- debug gem (for rdbg usage)
- An LLM provider gem

## License

MIT License

## Contributing

Bug reports and feature requests welcome at [GitHub Issues](https://github.com/rira100000000/girb/issues).
