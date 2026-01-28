# Agent Guidelines - Zorb Project

## Priorities
1. **Priority 0: Pass `CZECH` integration test.**
   - The prover `czech.z5` is the source of truth for V5 compliance.
   - Current state: "Indirect Opcodes" mostly passing.
   - Investigation area: `check_arg_count` (VAR:31) bitmask mismatch and 1-off error in `dec_chk` (2OP:4) with SP.

2. **Priority 1: Pass all other integration tests.**
   - Once `CZECH` is green, re-enable and pass `strictz.z5` and `unicode.z5`.

## Absolute Mandates
- **No New Features**: Do not implement meta-commands, sound, or advanced UI until Priority 0 and 1 are achieved.
- **WASM Scoping**: Remember that Elixir assignments inside Orb `if` blocks do NOT set WASM locals. Use `if/else` returns or helper functions.
- **PC Alignment**: Every instruction MUST consume exactly the number of operand bytes specified by its type prefix. Use `fetch_var_operand` to safely consume optional operands.
- **Variable References**: Opcodes taking a variable index (store, load, inc, dec, pull, etc.) must handle variable 0 as SP correctly (pop for index, then pop/push for value).

## Testing
- Run integration tests with: `mix test test/zorb_prover_test.exs`
- Integration tests use a non-blocking `Runner` with an asynchronous input buffer.
- Use `Expect.expect(pattern, timeout, task_pid)` to verify output.
- Use `Expect.dispute(pattern)` to fail early on known error strings (e.g., "ERROR").