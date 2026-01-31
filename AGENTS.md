# Agent Guidelines - Zorb Project

## Current Status (January 31, 2026 - Final)
- **CZECH (V5)**: Core logic is passing (406/425).
- **Unicode**: `unicode.z5` integration is passing.
- **Input**: `read_input` fixed to terminate on CR and handle V1-4 lowercase.
- **Fixtures**: Full set of Z1-Z7 provers/test-files available in `test/fixtures/provers`.
- **Blocked**: `strictz.z5` and `zil_test.z3` reaching prompts but failing to terminate gracefully in tests (timeout).

## Priorities
1. **Priority 0: Fix Test Synchronization.**
   - Ensure tests that reach "quit" or "completed" actually terminate without timing out `Task.await`.
2. **Priority 1: Multi-Version Coverage.**
   - Enable and pass integration tests for the new Z1, Z2, Z3, Z6, and Z7 fixtures.
3. **Priority 2: Specification Refinement.**
   - Implement bit-accurate `skip_name` per Spec 3.2.
   - Refactor `Zorb.Interpreter` into version-specialized modules.

## Absolute Mandates
- **No New Features**: No UI or sound until core Z1-Z8 compliance is achieved.
- **WASM Control Flow**: Use `Control.block` and `*.break()` for loop termination in Orb DSL.
- **Variable References**: Opcodes taking variable indices must follow Spec 14.3 (Variable 0 = peek/replace).

## Testing
- Run integration tests with: `mix test test/zorb_prover_test.exs`
- Use `Expect.expect(pattern, timeout, task_pid)` for output verification.
- Use `answer(pid, text)` for direct input injection.