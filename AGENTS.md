# Agent Guidelines - Zorb Project

- **Gold Standard Baseline**: Commit `414c2d9c5f3f02aa70a8bea97628bc1957664119` (or newer) is the verified "Gold Standard" for V1-V8 support (excluding V6).

## Current Status (February 17, 2026)
- **V1-V8 Support**: Full compliance (excluding V6) achieved and verified.
- **Save/Restore/Undo**: Full support for in-memory game state snapshots and undo stack implemented and verified.
- **UI & Screen Model**: Complete support for colors, sound bleeps, and window splitting/selection.
- **Instruction Tracing**: Removed for performance.
- **Internal Font 3**: Graphics are handled internally by the capsule.
- **Sidecar Payload**: Large stories are serialized to binary files at compile-time.
- **Silent Tests**: Logger levels are suppressed during tests, and session shutdown is now race-condition free.
- **Baking Factory**: Sourceror-based pipeline produces bespoke WASM capsules.
- **Tokenizer**: Handled entirely within the WASM capsule with O(1) dictionary lookups.

## Absolute Mandates
- **No New Features**: No UI or sound until core Z1-Z8 compliance (excluding V6) is achieved.
- **WASM Control Flow**: Use `Control.block` and `*.break()` for loop termination in Orb DSL.
- **Variable References**: Opcodes taking variable indices must follow Spec 14.3 (Variable 0 = peek/replace).
- **V6 Support**: NEVER attempt to implement V6. It is explicitly out of scope.

## Testing
- Run integration tests with: `mix test`
- Use `mix precommit` before any significant change to ensure standards and tests pass.
- **Commit Rules**: Milestone commits must NEVER use `--no-verify`. Only checkpoint commits are permitted to bypass pre-commit hooks.

