# Agent Guidelines - Zorb Project

## Development Baseline
- **Known Good Baseline**: Commit `cd3c1b7eaa3cc07e1271c1992cfe44538a76dda7` is the verified baseline for V1-V8 support (excluding V6). This commit is considered inviolable. All regressions must be checked against this state.

## Current Status (February 10, 2026)
- **V1-V8 Support**: Full compliance (excluding V6) achieved and verified via provers.
- **Resource Constraints**: Running in a harsh environment; integration test timeouts are set to 300s/120s.
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

