# girb (Generative IRB)

An AI assistant embedded in your IRB session. It understands your runtime context and helps with debugging and development.

[日本語版 README](README_ja.md)

## Features

- **Context Awareness**: Automatically understands local variables, instance variables, and self object
- **Exception Capture**: Automatically captures recent exceptions - just ask "why did this fail?" after an error
- **Session History Understanding**: Tracks IRB input history and understands conversation flow
- **Tool Execution**: AI autonomously executes code, inspects objects, and retrieves source code
- **Autonomous Investigation**: AI can loop through investigate-execute-analyze cycles using `continue_analysis`
- **Debug Gem Integration**: Use with Ruby's debug gem for step-through debugging with AI assistance
- **Multi-language Support**: Detects user's language and responds in the same language
- **Customizable**: Add custom prompts for project-specific instructions
- **Provider Agnostic**: Use any LLM provider or implement your own

## Installation

### For Rails Projects

Add to your Gemfile:

```ruby
group :development do
  gem 'girb-ruby_llm'  # or girb-gemini
end
```

Then run:

```bash
bundle install
```

Create a `.girbrc` file in your project root:

```ruby
# .girbrc
require 'girb-ruby_llm'

Girb.configure do |c|
  c.provider = Girb::Providers::RubyLlm.new(model: 'gemini-2.5-flash')
end
```

Now `rails console` will automatically load girb!

### For Non-Rails Projects

Install globally:

```bash
gem install girb girb-ruby_llm
```

Create a `.girbrc` file in your project directory:

```ruby
# .girbrc
require 'girb-ruby_llm'

Girb.configure do |c|
  c.provider = Girb::Providers::RubyLlm.new(model: 'gemini-2.5-flash')
end
```

Then use `girb` command instead of `irb`.

## How .girbrc Works

girb searches for `.girbrc` in the following order:

1. Current directory, then parent directories (up to root)
2. `~/.girbrc` as fallback

This allows you to:

- **Project-specific settings**: Place `.girbrc` in your project root
- **Shared settings**: Place `.girbrc` in a parent directory (e.g., `~/work/.girbrc` for all work projects)
- **Global default**: Place `.girbrc` in your home directory

## Providers

Currently available providers:

- [girb-ruby_llm](https://github.com/rira100000000/girb-ruby_llm) - Multiple providers via RubyLLM (OpenAI, Anthropic, Gemini, Ollama, etc.)
- [girb-gemini](https://github.com/rira100000000/girb-gemini) - Google Gemini

You can also [create your own provider](#custom-providers).

## Usage

### For Rails Projects

```bash
rails console
```

girb is automatically loaded via Railtie.

### For Non-Rails Projects

```bash
girb
```

### Debug with binding.girb

Insert `binding.girb` in your code:

```ruby
def problematic_method
  result = some_calculation
  binding.girb  # AI-powered IRB starts here
  result
end
```

### Debug with debug gem (rdbg)

For step-through debugging with AI assistance, add `require "girb"` to your script:

```ruby
require "girb"

def problematic_method
  result = some_calculation
  result
end

problematic_method
```

Then run with rdbg:

```bash
rdbg your_script.rb
```

In the debugger, use:
- `ai <question>` - Ask AI a question
- `Ctrl+Space` - Send current input to AI
- Natural language (non-ASCII) input is automatically routed to AI

The AI can execute debugger commands like `step`, `next`, `continue`, and set breakpoints for you.

### How to Ask AI

#### Method 1: Ctrl+Space

Press `Ctrl+Space` after typing to send your input as a question to AI.

```
irb(main):001> What's causing this error?[Ctrl+Space]
```

#### Method 2: qq command

```
irb(main):001> qq "How do I use this method?"
```

## Configuration Options

Add to your `.girbrc`:

```ruby
require 'girb-ruby_llm'

Girb.configure do |c|
  # Debug output (default: false)
  c.debug = true

  # Custom prompt (optional)
  c.custom_prompt = <<~PROMPT
    This is a production environment. Always confirm before destructive operations.
  PROMPT
end
```

### Command Line Options

```bash
girb --debug    # Enable debug output
girb -d         # Same as above
girb --help     # Show help
```

### Environment Variables

For `girb` command, you can also configure via environment variables (used when no `.girbrc` is found):

| Variable | Description |
|----------|-------------|
| `GIRB_PROVIDER` | Provider gem to load (e.g., `girb-ruby_llm`, `girb-gemini`) |
| `GIRB_MODEL` | Model to use (e.g., `gemini-2.5-flash`, `gpt-4o`) |
| `GIRB_DEBUG` | Set to `1` to enable debug output |

## Available Tools

| Tool | Description |
|------|-------------|
| `evaluate_code` | Execute Ruby code in IRB context |
| `inspect_object` | Inspect object details |
| `get_source` | Get source code of methods or classes |
| `list_methods` | List methods of an object |
| `find_file` | Search for files in the project |
| `read_file` | Read file contents |
| `session_history` | Get IRB session history |
| `continue_analysis` | Request context refresh for autonomous investigation |

### Additional Tools in Rails Environment

| Tool | Description |
|------|-------------|
| `query_model` | Execute queries on ActiveRecord models |
| `model_info` | Get model schema information |

### Additional Tools in Debug Mode (rdbg)

| Tool | Description |
|------|-------------|
| `run_debug_command` | Execute debugger commands (step, next, continue, break, etc.) |

## Custom Providers

Implement your own LLM provider:

```ruby
class MyProvider < Girb::Providers::Base
  def initialize(api_key:)
    @api_key = api_key
  end

  def chat(messages:, system_prompt:, tools:)
    # messages: Array of { role: :user/:assistant/:tool_call/:tool_result, content: "..." }
    # tools: Array of { name: "...", description: "...", parameters: {...} }

    # Call your LLM API here
    response = call_my_llm(messages, system_prompt, tools)

    # Return a Response object
    Girb::Providers::Base::Response.new(
      text: response.text,
      function_calls: response.tool_calls&.map { |tc| { name: tc.name, args: tc.args } }
    )
  end
end

Girb.configure do |c|
  c.provider = MyProvider.new(api_key: ENV['MY_API_KEY'])
end
```

## Examples

### Debugging Assistance

```
irb(main):001> user = User.find(1)
irb(main):002> user.update(name: "test")
=> false
irb(main):003> Why did the update fail?[Ctrl+Space]
Checking `user.errors.full_messages` shows validation errors:
- "Email can't be blank"
The email might be getting cleared when updating the name.
```

### Code Understanding

```
irb(main):001> Where is the User model defined in this project?[Ctrl+Space]
It's defined in app/models/user.rb.
```

### Pattern Recognition

```
irb(main):001> a = 1
irb(main):002> b = 2
irb(main):003> What would z be if I continue with c = 3 and beyond?[Ctrl+Space]
Following the pattern a=1, b=2, c=3..., z would be 26.
```

## Requirements

- Ruby 3.2.0 or higher
- IRB 1.6.0 or higher
- An LLM provider gem (girb-ruby_llm or girb-gemini)

## License

MIT License

## Contributing

Bug reports and feature requests are welcome at [GitHub Issues](https://github.com/rira100000000/girb/issues).
