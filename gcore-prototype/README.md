# Gcore

Shared core library for AI-powered Ruby debugging tools.

Gcore provides the common components used by:
- **girb** - AI assistant for IRB
- **gdebug** - AI assistant for Ruby's debug gem

## Installation

```ruby
gem 'gcore'
```

## Components

### Providers

Interface for LLM providers. Implement `Gcore::Providers::Base` to add new AI backends.

```ruby
class MyProvider < Gcore::Providers::Base
  def chat(messages:, system_prompt:, tools:, binding: nil)
    # Call your LLM API
    Response.new(text: "Hello!")
  end
end
```

Available providers (separate gems):
- `girb-ruby_llm` - Uses ruby_llm gem (OpenAI, Anthropic, etc.)
- `girb-gemini` - Google Gemini API

### Tools

AI tools for runtime inspection:

| Tool | Description |
|------|-------------|
| `evaluate_code` | Execute Ruby code in context |
| `inspect_object` | Inspect object details |
| `get_source` | Get method/class source code |
| `list_methods` | List available methods |
| `read_file` | Read source files |
| `find_file` | Find files by pattern |
| `get_current_directory` | Get current directory |

### Configuration

```ruby
require "gcore"
require "girb-ruby_llm"

Gcore.configure do |c|
  c.provider = Girb::Providers::RubyLlm.new
  c.debug = true  # Enable debug output
  c.custom_prompt = "Additional instructions..."
end
```

### AI Client

```ruby
client = Gcore::AiClient.new
context = Gcore::ContextBuilder.new(binding).build
client.ask("What is x?", context, binding: binding)
```

## Architecture

```
┌─────────────────────────────────────────────┐
│                   gcore                      │
├─────────────────────────────────────────────┤
│  Providers::Base    - LLM interface          │
│  AiClient           - AI communication       │
│  ContextBuilder     - Runtime context        │
│  Tools              - AI capabilities        │
│  ConversationHistory - Multi-turn support    │
│  PromptBuilder      - System prompts         │
│  Configuration      - Settings               │
└─────────────────────────────────────────────┘
        ↑                       ↑
        │                       │
   ┌────┴────┐             ┌────┴────┐
   │  girb   │             │ gdebug  │
   │  (IRB)  │             │ (debug) │
   └─────────┘             └─────────┘
```

## License

MIT
