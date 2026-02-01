# girb (Generative IRB)

An AI assistant embedded in your IRB session. It understands your runtime context and helps with debugging and development.

[日本語版 README](README_ja.md)

## Features

- **Context Awareness**: Automatically understands local variables, instance variables, and self object
- **Exception Capture**: Automatically captures recent exceptions - just ask "why did this fail?" after an error
- **Session History Understanding**: Tracks IRB input history and understands conversation flow
- **Tool Execution**: AI autonomously executes code, inspects objects, and retrieves source code
- **Multi-language Support**: Detects user's language and responds in the same language
- **Customizable**: Add custom prompts for project-specific instructions
- **Provider Agnostic**: Use Gemini, OpenAI, or implement your own LLM provider

## Installation

Add to your Gemfile:

```ruby
gem 'girb'
gem 'girb-gemini'  # or other provider
```

Then run:

```bash
bundle install
```

Or install directly:

```bash
gem install girb girb-gemini
```

## Setup

### Using Gemini (Recommended)

Set your API key as an environment variable:

```bash
export GEMINI_API_KEY=your-api-key
```

Add to your `~/.irbrc`:

```ruby
require 'girb-gemini'
```

That's it! The Gemini provider auto-configures when `GEMINI_API_KEY` is set.

### Using Other Providers

Implement your own provider or use community providers:

```ruby
require 'girb'

Girb.configure do |c|
  c.provider = MyCustomProvider.new(api_key: "...")
end
```

See [Custom Providers](#custom-providers) for implementation details.

## Usage

### Quick Start

```bash
girb
```

Or add to your `~/.irbrc` for automatic loading:

```ruby
require 'girb-gemini'
```

Then use regular `irb` command.

### Debug with binding.girb

Insert `binding.girb` in your code:

```ruby
def problematic_method
  result = some_calculation
  binding.girb  # AI-powered IRB starts here
  result
end
```

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

Add to your `~/.irbrc`:

```ruby
require 'girb-gemini'

Girb.configure do |c|
  # Provider configuration (girb-gemini auto-configures, but you can customize)
  c.provider = Girb::Providers::Gemini.new(
    api_key: ENV['GEMINI_API_KEY'],
    model: 'gemini-2.5-flash'
  )

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

### Additional Tools in Rails Environment

| Tool | Description |
|------|-------------|
| `query_model` | Execute queries on ActiveRecord models |
| `model_info` | Get model schema information |

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
- An LLM provider (e.g., girb-gemini)

## License

MIT License

## Contributing

Bug reports and feature requests are welcome at [GitHub Issues](https://github.com/rira100000000/girb/issues).
