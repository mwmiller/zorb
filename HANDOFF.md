# Handoff: Zorb "Bespoke" Architecture Pivot

## Current State
The project has successfully pivoted from a generic runtime interpreter to a **Game Capsule** architecture. Every Z-machine story is now compiled into its own optimized WASM binary.

### Progress
- **Logic Isolation**: All Z-machine instructions are in `lib/zorb/interpreter/logic_body.exs`.
- **Compile-Time Branching**: Added `v_at_least` macro to optimize version-specific logic at compile-time.
- **Persistent Caching**: Implemented a caching system in `Zorb.Capsule` that stores artifacts in `tmp/zorb_cache/<version>/`.
- **Host Contract**: Defined `Zorb.Capsule.Host` and documented it in `CAPSULE_HOST.md`.
- **Test Suite**: Refactored `test/zorb_prover_test.exs` to use dynamic capsules. Legacy `Interpreter` tests have been deleted.

## Known Challenges
- **Large Story Compilation**: Initial compilation of large story files (like Zork) is slow due to the massive AST transformation (thousands of `var!` wrappers). Caching resolves this for subsequent runs, but the first-run experience needs optimization.
- **Hygiene & Macros**: The current robust solution uses `Code.string_to_quoted!` and `quote unquote: false` to bypass Elixir's macro hygiene for WASM local variables. This works but is heavy.

## Immediate Tasks for Next Agent
1. **Verify All Provers**: Run `mix test test/zorb_prover_test.exs` and ensure all tests pass (expect a long first run).
2. **Optimize First-Run "Baking"**:
    - Explore pre-parsing `logic_body.exs` into a "template" AST to avoid repeated parsing.
    - Reduce the number of `var!` wrappers if possible, or move them into the source file permanently.
3. **Capabilities Implementation**: Ensure `get_capabilities` is fully utilized in the logic to enable/disable features like Font 3.
4. **WASM Size Optimization**: Check if generated capsules can be further minimized (e.g., pruning unused instructions).

## Caching Reference
- Version: `0.1.0-alpha.1`
- Directory: `tmp/zorb_cache/0.1.0-alpha.1/`
- Key Format: `<version>-<size>-<header_hash_prefix>`
