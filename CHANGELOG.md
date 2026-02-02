# Changelog

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
