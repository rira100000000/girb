# Changelog

## [0.4.2] - 2026-02-13

### Added

- Show tool execution details (name, arguments, results) in human-readable format during AI operation
- Add detailed debug logging for provider responses and messages (`c.debug = true`)

### Changed

- Reinforce Ruby environment context in system prompts to reduce provider-specific function call errors
- Provider-agnostic error handling: display `response.error` summary to user without retrying

### Fixed

- Fix AI sometimes responding in Japanese regardless of user's language
  - Replace Japanese auto-continue messages in IRB-to-debug transition with English
  - Replace Japanese placeholder text in session history with English
  - Remove Japanese example from debug prompt greeting detection

## [0.4.1] - 2026-02-12

### Fixed

- Fix AI always responding in Japanese regardless of user's language
  - Replaced Japanese-only examples in system prompt with English examples
  - Added explicit instruction to match user's language in tool comments

## [0.4.0] - 2026-02-12

### Added

- Add web search support note for girb-gemini provider in README

### Fixed

- Always record assistant message in conversation history even when response text is empty
  - Maintains user/assistant message alternation required by some providers (e.g. Gemini with web search)

## [0.3.3] - 2026-02-08

### Fixed

- Fix Rails console prompt referencing non-existent tools (`model_info`, `query_model`)
  - Corrected to actual tool names: `rails_model_info`, `rails_project_info`

## [0.3.2] - 2026-02-08

### Added

- Show real-time progress feedback during tool execution (AI now explains each step as it works)
- Generic `metadata` field for tool calls to support provider-specific data pass-through (e.g. Gemini 3 `thought_signature`)

### Changed

- Improved breakpoint tracking pattern: self-initializing `$tracked ||= []` in conditions to prevent nil errors

### Fixed

- Fix process crash when pressing Ctrl+C during AI API call in debug mode
  - SIGINT now sets interrupt flag instead of propagating to main thread's `Queue.pop`
  - Pending debug commands are properly discarded on interrupt
  - Original SIGINT handler is always restored via `ensure` block
- Save session history on every AI turn instead of only at exit, preventing data loss on crash or unexpected exit

## [0.3.0] - 2026-02-07

### Added

- **Session persistence**: Persist AI conversation history across sessions
  - Enable with `Girb.debug_session = "session_name"`
  - `qq session status/list/clear` commands for session management
  - Sessions saved to `.girb/sessions/<session_id>.json`
  - Auto-cleanup of sessions inactive for 7+ days
  - Works in both IRB and debug modes
- **Persisted conversations in `get_session_history` tool**
  - Access previous session's AI conversations
- **`run_debug_command` tool for IRB mode**
  - AI can now execute debug commands (next, step, continue, etc.) in `binding.girb`
  - Enables autonomous step-by-step debugging in IRB sessions
- **Seamless `binding.girb` to debug mode transition**
  - When AI executes debug commands (next, step, etc.) in `binding.girb`, automatically transitions to debug mode
  - Original user instruction is preserved and passed to debug mode for continuous execution
  - AI can autonomously step through code with `auto_continue: true`

### Changed

- Debug mode AI command changed from `ai` to `qq` (consistent with IRB mode)
- Separate prompts for different modes (auto-detected):
  - Breakpoint mode (`binding.girb`): Focus on actual code in file
  - Interactive mode (`girb` command): Focus on session history
  - Rails mode (`rails console`): Rails-specific guidance
- Debug commands in IRB mode are now injected via `ReadmultilinePatch` to ensure proper execution at IRB's top level
- Improved debug prompt to prefer conditional breakpoints for loops (efficient) over repeated stepping (slow)
- Continuation message now warns AI not to re-execute already-run commands

### Fixed

- Exclude forwardable from exception capture (false SyntaxError detection)
- Exclude rubygems from exception capture (false LoadError during gem activation)
- Fix `binding.girb` Ctrl+Space keybinding registration
- Fix `binding.girb` not loading `.girbrc` (provider configuration missing)
- Fix `binding.girb` to properly pass binding context (debug commands now work on user's script)
- Fix deadlock when making API calls in debug mode by temporarily disabling Ruby's `Timeout` module
- Fix `GIRB_DIR` constant scope for proper frame filtering in debugger

## [0.2.0] - 2026-02-05

### Added

- **Debug gem (rdbg) integration**: AI assistant for step-through debugging
  - `qq <question>` command in debugger
  - Ctrl+Space to send input to AI
  - Auto-routing of non-ASCII (Japanese) input to AI
  - `run_debug_command` tool for AI to execute debugger commands (step, next, continue, break, etc.)
- **Auto-continue for autonomous AI investigation**
  - `continue_analysis` tool for IRB mode context refresh
  - AI can loop through investigate-execute-analyze cycles
  - Configurable iteration limits (MAX_ITERATIONS = 20)
- **Ctrl+C interrupt support** for both IRB and debug modes
  - Graceful interruption of long-running AI operations
  - AI summarizes progress when interrupted
- **Debug session history tracking**
  - Track debugger commands and AI conversations
  - `get_session_history` tool for debug mode
- **Efficient variable tracking** with silent breakpoints
  - `break file:line if: ($var << x; false)` pattern for recording without stopping

### Changed

- Separate tool sets for IRB and debug modes
  - SHARED_TOOLS: Common tools for both modes
  - IRB_TOOLS: SessionHistoryTool, ContinueAnalysis
  - DEBUG_TOOLS: DebugSessionHistoryTool, RunDebugCommand
- Improved prompts for debug mode
  - Guidance on variable persistence across frames
  - Instructions for efficient breakpoint usage
  - Context-aware investigation (don't use tools for greetings)

### Fixed

- Tool calls now include IDs for proper conversation history
- Auto-continue loop properly exits when debug commands are queued

## [0.1.2] - 2026-02-03

### Added

- `.girbrc` configuration file support with directory traversal
- Railtie for automatic Rails console integration
- GirbrcLoader utility for finding and loading `.girbrc` files
- `get_current_directory` tool for non-Rails environments

### Changed

- Recommend `.girbrc` configuration instead of `~/.irbrc`
- `girb` command now loads `.girbrc` before falling back to environment variables

## [0.1.1] - 2026-02-03

### Changed

- GIRB_PROVIDER environment variable is now required for `girb` command
- Recommend ~/.irbrc configuration instead of environment variables
- Remove legacy configuration (gemini_api_key, model accessors)
- Remove built-in provider auto-detection

### Added

- GIRB_MODEL environment variable support

## [0.1.0] - 2025-02-02

### Added

- Initial release
- AI-powered IRB assistant with `qq` command
- Provider-agnostic architecture supporting multiple LLM backends
- Tools: evaluate_code, read_file, find_file, get_source, inspect_object, list_methods
- Rails integration with model inspection tools
- Session history support
- Exception capture and context building
- Custom prompt configuration
- Debug mode
