# girb (Generative IRB)

An AI assistant embedded in your IRB session. It understands your runtime context and helps with debugging and development.

[日本語版 README](README_ja.md)

## Features

- **Context Awareness**: Automatically understands local variables, instance variables, and recent exceptions
- **Session History Understanding**: Tracks IRB input history and understands conversation flow
- **Tool Execution**: AI autonomously executes code, inspects objects, and retrieves source code
- **Multi-language Support**: Detects user's language and responds in the same language
- **Customizable**: Add custom prompts for project-specific instructions

## Installation

Add to your Gemfile:

```ruby
gem 'girb'
```

Then run:

```bash
bundle install
```

Or install directly:

```bash
gem install girb
```

## Setup

### Configure API Key

Set your Gemini API key as an environment variable:

```bash
export GEMINI_API_KEY=your-api-key
```

Or configure in `.irbrc`:

```ruby
Girb.configure do |c|
  c.gemini_api_key = 'your-api-key'
end
```

## Usage

### Start with girb command

```bash
girb
```

### Use in existing IRB session

```ruby
require 'girb'
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

#### Method 3: AI Chat Mode

```
irb(main):001> qq-chat
[girb] AI Mode ON - Ask questions in natural language (exit: qq-chat)
irb(main):002> I want to check the user object's attributes
```

In chat mode, prefix with `>` to execute Ruby code:

```
irb(main):003> > user.attributes
```

## Configuration Options

```ruby
Girb.configure do |c|
  # API key (required)
  c.gemini_api_key = ENV['GEMINI_API_KEY']

  # Model to use (default: gemini-2.5-flash)
  c.model = 'gemini-2.5-flash'

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
- Gemini API key

## License

MIT License

## Contributing

Bug reports and feature requests are welcome at [GitHub Issues](https://github.com/rira/girb/issues).
