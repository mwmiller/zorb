# Agent Guidelines - Zorb Project

## Current Status (January 31, 2026)
- **CZECH (V5)**: Core logic is passing. Summary: "Passed: 406, Failed: 0."
- **Indirect Opcodes**: Successfully implemented correct SP handling (Spec 14.3) for `load`, `store`, `inc`, `dec`, `inc_chk`, `dec_chk`, and `pull`.
- **Unicode**: `unicode.z5` integration is passing.
- **V3 Support**: Added `czech.z3` integration; memory increased and stack moved to accommodate larger V3/V5 story files.
- **Blocked**: `strictz.z5` is currently timing out on input prompts.

## Priorities
1. **Priority 0: Stabilize `CZECH` V3 and V5.**
   - Ensure `czech.z3` and `czech.z5` pass reliably in CI.
   - Investigate why `czech.z3` output matching is brittle.

2. **Priority 1: Pass `StrictZ`.**
   - Resolve terminal/input synchronization issues causing timeouts.
   - Address any functional failures reported by `strictz.z5` (e.g., `get_next_prop`).

3. **Priority 2: Opcode DSL Refactor.**
   - Recover the `defopcode` refactor from the `refactor/opcode-dispatch-and-core-logic` stash.
   - Transition from manual `if/else` dispatch to declarative "Delegated Dispatch" to improve maintainability.

## Absolute Mandates
- **No New Features**: Do not implement meta-commands, sound, or advanced UI until Priority 0 and 1 are achieved.
- **WASM Scoping**: Remember that Elixir assignments inside Orb `if` blocks do NOT set WASM locals. Use `if/else` returns or helper functions.
- **PC Alignment**: Every instruction MUST consume exactly the number of operand bytes specified by its type prefix.
- **Variable References (Spec 14.3)**: Indirect opcodes must handle Variable 0 (SP) as peek/replace, NOT pop/push.

## Testing
- Run integration tests with: `mix test test/zorb_prover_test.exs`
- Use `Expect.expect(pattern, timeout, task_pid)` to verify output.
- Use `Expect.dispute(pattern)` to fail early on known error strings.
