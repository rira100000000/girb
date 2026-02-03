# Changelog

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
