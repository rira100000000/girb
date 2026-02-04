# gdebug

AI-powered debugging assistant for Ruby's debug gem. Works with VSCode, RubyMine, and terminal debuggers.

## Installation

```bash
gem install gdebug
```

## Setup

Create a `.gdebugrc` file:

```ruby
# .gdebugrc
require "girb-ruby_llm"  # or any girb provider

Gdebug.configure do |c|
  c.provider = Girb::Providers::RubyLlm.new
  # c.debug = true  # Enable debug output
end
```

## Usage

### With rdbg (terminal)

```bash
rdbg -r gdebug your_script.rb
```

At any breakpoint, use the `ai` command:

```
(rdbg) ai Why is this variable nil?
(rdbg) ai What does this method do?
(rdbg) ai How can I fix this error?
```

### In your code

```ruby
require "gdebug"

def problematic_method
  result = some_calculation
  debugger  # Stops here, AI assistant available
  result
end
```

### With VSCode

1. Install the "Ruby LSP" extension
2. Add to your `.vscode/launch.json`:

```json
{
  "type": "ruby_lsp",
  "request": "launch",
  "program": "${file}",
  "env": {
    "RUBYOPT": "-rgdebug"
  }
}
```

3. Use the Debug Console to run `ai` commands

## Available AI Commands

| Command | Description |
|---------|-------------|
| `ai <question>` | Ask a question about the current context |

## AI Tools

The AI assistant has access to:

- **evaluate_code**: Execute Ruby code in the current context
- **inspect_object**: Inspect variables and objects in detail
- **get_source**: View method and class source code
- **list_methods**: List methods on objects
- **read_file**: Read source files
- **find_file**: Find files in the project

## Providers

gdebug uses the same providers as [girb](https://github.com/example/girb):

- `girb-ruby_llm` - Ruby LLM (OpenAI, Anthropic, Google, etc.)
- `girb-gemini` - Google Gemini
- Or create your own

## License

MIT
