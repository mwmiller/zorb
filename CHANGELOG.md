# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.8.0] - 2026-02-19

### Added
- **LRU Cache Pruning**: Introduced `Zorb.prune_cache/1` to manage the compilation cache based on file count, total size, or age using a Least-Recently-Used (LRU) policy.
- **Robust Cache Invalidation**: The cache hash now includes the compiler version and story data byte size, ensuring that updates to Zorb automatically trigger re-compilation of existing story files.

### Changed
- **Cache Hit Behavior**: Loading from the cache now "touches" the cached `.wasm` file, updating its modification time to support LRU pruning.

## [0.7.0] - 2026-02-19

### Added
- **Story Analysis Engine**: Introduced `Zorb.Inspector` for semantic analysis of Z-machine story files.
- **Orbit Radio Metadata**: Game Capsules now bake evocative, dictionary-matched metadata (chat tags, user labels, and command prefixes) into memory.
- **Enhanced Host API**: Added `Zorb.metadata/1` and `Zorb.Session.metadata/1` for easy retrieval of story-specific social metadata.
- **New ZIO Exports**: All capsules now export `zio_get_*` functions for version, serial, and Orbit Radio metadata.

### Fixed
- Improved robustness of dictionary scanning to handle empty or minimal story dictionaries without crashing.

## [0.6.0] - 2026-02-18

### Changed
- **Removed Runners**: Zorb.Session and Zorb.CLI have been moved to the test suite to eliminate mandatory wasmex dependency for end users.
- **Pure Elixir Focus**: wasmex is now an optional dependency, only required for development and testing.
- **API Simplification**: Zorb.run/2 has been removed. Use Zorb.compile/2 to generate WASM capsules.

## [0.5.1] - 2026-02-18

### Added
- **External State Management**: Trigger `save`, `restore`, and `undo` operations directly from the Elixir host using `Zorb.Session.save/1`, etc.
- **Cooperative Interrupt System**: A new polling mechanism allows the Host to safely perform state snapshots without deadlocking the Z-machine loop.
- **Comprehensive ZIO Exports**: The Game Capsule now exports all Z-machine system functions with a `zio_` prefix, providing a full control interface for custom Host implementations.
- **Cache Management**: Added `Zorb.clear_cache/0` to easily purge generated WASM artifacts and temporary payloads.

### Changed
- Refactored WASM Host imports to use context-aware memory access for improved thread safety.
- Optimized `Zorb.Session` to handle shutdown race conditions gracefully during test execution.

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
