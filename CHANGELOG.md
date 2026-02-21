# Changelog

## [0.9.1] - 2026-02-21

### Fixed
- Template generation now uses lazy loading with persistent_term caching to avoid compile-time module dependency issues

## [0.9.0] - 2026-02-21

### Added
- **WASM Patcher**: Blazing-fast compilation using pre-compiled templates (~1ms per story, 6000x speedup)
- Compile-time template generation for all Z-machine versions (V1-V8, excluding V6)
- `Zorb.Patcher` module for fast compilation
- `Zorb.Templates` module with embedded pre-compiled WASM templates
- `:method` option to `Zorb.compile/2` (`:patcher` or `:traditional`)

### Changed
- **Breaking**: Patcher is now the default compilation method
- Updated to Watusi 0.4.0 (adds WASM patcher support)
- Improved performance documentation with detailed profiling results
- Memory overhead: 335 KB for all templates (one-time cost)

### Performance
- Compilation time: ~1ms (down from ~4000ms)
- Speedup: 6000x over traditional compilation
- Cache support: Works with both patcher and traditional methods

## [0.8.0] - 2026-02-18

### Added
- Enhanced cache management and metadata access
- Version branch pruning implementation
- Comprehensive profiling instrumentation

### Changed
- Converted conditionals to use pattern matching over if statements
- Improved AST manipulation performance

## [0.7.0] - 2026-02-15

### Added
- Story metadata support
- Inspector module for analyzing story files

## [0.6.0] - 2026-02-10

### Changed
- Moved runners to test suite
- Made WASMex optional dependency
- Pure library focus (no CLI)

## [0.5.1] - 2026-02-05

### Changed
- Upgraded Watusi to 0.2.0

## [0.5.0] - 2026-02-01

### Added
- External state management
- ZIO exports for host interface
- Save, restore, and undo support

## [0.4.0] - 2026-01-25

### Added
- Initial public release
- Full V1-V8 support (excluding V6)
- Bespoke WASM capsule generation
