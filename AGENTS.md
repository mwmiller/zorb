# Agent Guidelines - Zorb Project

## Development Baseline
- **Gold Standard Baseline**: Commit `9d1104c6282cac6757875ab9af94f18ea43123ef` is the verified "Gold Standard" for V1-V8 support (excluding V6). This commit is considered inviolable and includes the Sidecar Payload optimization for large story compilation. All regressions must be checked against this state.

## Current Status (February 12, 2026)
- **V1-V8 Support**: Full compliance (excluding V6) achieved and verified via provers and integration tests (including Lost Pig V8).
- **Sidecar Payload**: Large stories are serialized to binary files at compile-time to prevent Elixir compiler hangs.
- **Silent Tests**: Logger levels are suppressed during tests to focus on failures.
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

