# Agent Guidelines - Zorb Project

## Current Status (February 1, 2026)
- **CZECH (V5)**: Core logic is passing (100%). Full V5 compliance achieved.
- **Unicode**: `unicode.z5` integration is passing.
- **Input**: `read_input` fixed to handle V1-3 buffer limits correctly.
- **Tokenization**: `tokenize` host function implemented in Elixir, enabling command parsing for ZILF and Inform games.
- **Fixtures**: `strictz.z5`, `zil_test.z3`, and `simple_test.z7` integration tests are now passing.
- **Version Support**: Versions 1-5 and 7-8 are supported. **Version 6 is explicitly unsupported** due to its excessive graphical complexity and fundamentally different screen model.

## Priorities
1. **Priority 0: V1-V3 Stability.**
   - Resolve illegal opcodes in Zork 1 (V1/V2).
   - Perfect relative alphabet shifts (Spec 3.2.2).
2. **Priority 1: Specification Refinement.**
   - Refactor `Zorb.Interpreter` into version-specialized modules.
   - Consolidate ZSCII/Unicode conversion logic into a dedicated WASM module.
3. **Priority 2: V8 Support.**
   - Enable and pass integration tests for Z8 fixtures.

## Absolute Mandates
- **No New Features**: No UI or sound until core Z1-Z8 compliance (excluding V6) is achieved.
- **WASM Control Flow**: Use `Control.block` and `*.break()` for loop termination in Orb DSL.
- **Variable References**: Opcodes taking variable indices must follow Spec 14.3 (Variable 0 = peek/replace).
- **V6 Support**: NEVER attempt to implement V6 graphical opcodes or the V6 canvas model. V6 is out of scope.

## Testing
- Run integration tests with: `mix test test/zorb_prover_test.exs`
- Use `Expect.expect(pattern, timeout, task_pid)` for output verification.
- Use `answer(pid, text)` for direct input injection.