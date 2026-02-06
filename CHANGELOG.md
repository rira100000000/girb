# Changelog

## [0.3.0] - 2026-02-06

### Added

- **Session persistence**: Persist AI conversation history across sessions
  - Enable with `Girb.debug_session = "session_name"`
  - `qq session status/list/clear` commands for session management
  - Sessions saved to `.girb/sessions/<session_id>.json`
  - Auto-cleanup of sessions inactive for 7+ days
  - Works in both IRB and debug modes
- **Persisted conversations in `get_session_history` tool**
  - Access previous session's AI conversations

### Changed

- Debug mode AI command changed from `ai` to `qq` (consistent with IRB mode)

### Fixed

- Exclude forwardable from exception capture (false SyntaxError detection)
- Exclude rubygems from exception capture (false LoadError during gem activation)
- Fix `binding.girb` Ctrl+Space keybinding registration
- Fix `binding.girb` not loading `.girbrc` (provider configuration missing)

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
