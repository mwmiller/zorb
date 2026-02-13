# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
