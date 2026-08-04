# Changelog

## [0.10.0] - 2026-08-04

### Changed
- Upgraded Watusi to 0.6.2 (spec-suite byte parity with `wasm-tools`, GC/ref proposals)
- Upgraded `usage_rules` to 1.2, `sourceror` to 1.12, `ex_doc` to 0.40, `credo` to 1.7.19

### Fixed
- Cache invalidation now accounts for the Watusi and Orb versions, preventing stale capsules after dependency upgrades
- Dictionary hash table generation now raises a clear error instead of looping forever when a story exceeds the 2048-entry capacity
- Unsupported Z-machine versions (including V6) raise a clear `ArgumentError` at compile time
- Eliminated compiler warnings (Elixir 1.20 bitstring pin operators, unused requires)

### Maintainability
- Consolidated duplicated alphabet, metadata, and Unicode table generation into a single shared data generator used by both patcher and traditional compilation
- Temporary payload files are cleaned up after traditional compilation

## [0.9.2] - 2026-02-23

### Improved
- Reduced impedance mismatch between Zorb and Watusi patching
- Got rid of stupid LLM written Hex desciption in favor of a more concise and accurate one

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
