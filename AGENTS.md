# Agent Guidelines - Zorb Project

- **Gold Standard Baseline**: Commit `414c2d9c5f3f02aa70a8bea97628bc1957664119` (or newer) is the verified "Gold Standard" for V1-V8 support (excluding V6).

## Current Status (February 18, 2026)
- **V0.6.0 Transformation**: Zorb is now a pure Elixir library for compiling Z-machine stories into standalone WASM capsules.
- **Runners Moved**: `Zorb.Session` and `Zorb.CLI` have been moved to `test/support/` to eliminate mandatory WASMex dependencies for end users.
- **V1-V8 Support**: Full compliance (excluding V6) achieved and verified.
- **Baking Factory**: Sourceror-based pipeline produces bespoke WASM capsules.
- **Tokenizer**: Handled entirely within the WASM capsule with O(1) dictionary lookups.

## Absolute Mandates
- **No New Features**: No UI or sound until core Z1-Z8 compliance (excluding V6) is achieved.
- **WASM Control Flow**: Use `Control.block` and `*.break()` for loop termination in Orb DSL.
- **Variable References**: Opcodes taking variable indices must follow Spec 14.3 (Variable 0 = peek/replace).
- **V6 Support**: NEVER attempt to implement V6. It is explicitly out of scope.

## Testing
- Run integration tests with: `mix test`
- All tests now leverage the internal `Zorb.Session` host in `test/support/`.
- Use `mix precommit` before any significant change to ensure standards and tests pass.
- **Commit Rules**: Milestone commits must NEVER use `--no-verify`. Only checkpoint commits are permitted to bypass pre-commit hooks.

