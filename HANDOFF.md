# Handoff - January 31, 2026

# New sources

A new repository with similar goals has been located at: https://github.com/DeMille/encrusted ... Review its progress, testing, tradeoffs, and implementation details to improve the corectness and performance.

## Current Status
Significant progress made on **CZECH** prover (czech.z5). Most core sections are now passing, including Subroutines and **Indirect Opcodes**. **Unicode** prover (unicode.z5) is now passing.

### Improvements & Fixes
- **CZECH Indirect Opcodes PASSING**: Fixed the long-standing bug in variable indirection. Opcodes like `load`, `store`, `pull`, `inc`, `dec`, `inc_chk`, and `dec_chk` now correctly handle Variable 0 (SP) per Spec 14.3 (peek/replace/pop behavior).
- **V5 Opcode Expansion**: Added implementations or stubs for `catch` (0OP:9), `throw` (2OP:28), `piracy` (0OP:15), `check_arg_count` (VAR:31), `save` (EXT:0), and `restore` (EXT:1).
- **je (2OP:1) Fix**: Corrected the dispatcher to fetch up to 4 operands when `je` is encoded in Variable form (bit 5=0), fixing early-exit branches.
- **check_arg_count (VAR:31)**: Fully implemented by storing the calculated argument count in the subroutine call frame (bits 8-15 of the result-variable word).
- **Runner Stability**: Increased steps per loop and timeouts in `Zorb.Runner` to ensure long-running provers like `strictz` and `czech` complete reliably.
- **Spec 14.3 Compliance**: Implemented `read_variable_peek` and `write_variable_replace` to handle SP references without unintended stack mutation.

### Blockers / Pending Issues
1. **strictz.z5 Timeout**: While core opcodes are now more accurate, `strictz.z5` is currently timing out in the test suite. This may be due to the increased complexity of the interpreter loop or specific test expectations.
2. **get_next_prop (1OP:1)**: Still needs investigation in `strictz.z5`. Property length decoding for V4+ headers requires more robust testing.
3. **Opcode DSL Refactor**: A declarative DSL refactor (`defopcode`) is currently stashed on the `refactor/opcode-dispatch-and-core-logic` branch. It successfully solves Elixir compiler "hangs" by using "Delegated Dispatch" (isolated functions per opcode) but needs stabilization of macro hygiene before merging.

### Next Steps
- Investigate and resolve `strictz.z5` timeouts and functional failures.
- Consolidate "Variable Reference" logic (Spec 14.3) across the interpreter to reduce duplication.
- Re-evaluate and stabilize the `defopcode` DSL to improve engine maintainability.
- Begin Phase 2 of Zorbit: Refactoring `Zorb.Interpreter` into a version-specific generator.