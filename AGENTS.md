# Agent Guidelines - Zorb Project

- **Gold Standard Baseline**: Commit `414c2d9c5f3f02aa70a8bea97628bc1957664119` is the verified "Gold Standard" for V1-V8 support (excluding V6). This commit includes the Sidecar Payload optimization and the removal of `log_step` instruction tracing.

## Current Status (February 13, 2026)
- **V1-V8 Support**: Full compliance (excluding V6) achieved and verified via provers and integration tests.
- **Instruction Tracing**: Completely removed from the interpreter and host interface for performance.
- **Sidecar Payload**: Large stories are serialized to binary files at compile-time to prevent Elixir compiler hangs.
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

