# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.4.0] - 2026-02-17

### Added
- Full support for Z-machine `save` and `restore` opcodes across all supported versions (V1-V5, V7-V8).
- Full support for Z-machine `undo` opcodes (`save_undo` and `restore_undo`) for V5+ stories.
- `Zorb.Session` now automatically manages game state snapshots and a 16-level undo stack in memory.

### Fixed
- Fixed redundant and slightly incorrect `log_shift` implementation in the interpreter's extended opcode handler.

## [0.3.0] - 2026-02-16

### Added
- Integrated `watusi` for converting WAT to binary WASM.
- Binary WASM is now the primary artifact produced by the "Baking Factory".

### Changed
- Caching logic updated to store and load binary `.wasm` capsules instead of `.wat`.
- Refactored compilation pipeline to reduce intermediate artifacts and variables.

## [0.2.0] - 2026-02-13

### Added
- Full support for Z-machine versions 1-5, 7, and 8.
- "Baking Factory" architecture using Orb to compile stories into bespoke WASM capsules.
- O(1) dictionary lookups via baked-in hash tables.
- UI support for colors, sound bleeps, and window management (splitting, selecting, erasing).
- Character graphics (Font 3) mapping to Unicode.
- Async `Zorb.Session` for easy integration with Phoenix and other Elixir applications.
- CLI wrapper for running stories directly.

### Changed
- Removed instruction tracing for significant performance improvements.
- Optimized sidecar payload handling for large story files.

### Removed
- Version 6 support (explicitly out of scope).
