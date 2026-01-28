# Handoff - January 28, 2026

## Current Status
Significant progress made on **CZECH** prover (czech.z5). Most core sections are now passing, including Subroutines and most Indirect Opcodes.

### Improvements & Fixes
- **Spec 14.3 Compliance**: Implemented "variable reference" behavior for `load`, `store`, `inc`, `dec`, `inc_chk`, `dec_chk`, and `pull`. Variable 0 (SP) correctly performs peek/replace/pop as required.
- **Subroutine Frame Standardization**: Standardized the 4-word frame structure (Return PC Low/High, Store Var/Arg Mask, Old FP).
- **Call Stack Separation**: Separated the evaluation stack from the call stack. Call frames and local variables are now stored on the `call_stack`, while Variable 0 operates on the `evaluation_stack`.
- **check_arg_count (VAR:31)**: Fixed to correctly read the argument mask from the call frame on the call stack. This test section is now passing.
- **WASM/Orb Robustness**: Refactored logic to use explicit `if/else` assignments to circumvent WASM local scoping bugs.
- **ZORBIT.md**: Created a design document outlining the Specialized Compiler Model and Game Capsule architecture.

### Blockers / Pending Issues
1. **ERROR [328/334] (pull)**: Still encountering stack pointer issues with `pull`.
   - **The Problem**: When `pull` has an operand of "Variable" type (indirection), there is a conflict between fetching the destination index and pulling the value.
   - **Current State**: Using `fetch_raw_operand` avoids the double-pop on `pull 0` but fails on `pull [rpointer]` because the indirection is missed. 
   - **Required Fix**: `pull` needs a specialized fetch phase that peeks at the stack for the index (if Variable 0) without consuming the value intended for the pull itself.

### Next Steps
- Implement a specialized indirection handler for `pull` that safely fetches the destination index.
- Finalize "Indirect Opcodes" section in CZECH.
- Re-enable and pass `strictz.z5`.
- Begin Phase 2 of Zorbit: Refactoring `Zorb.Interpreter` into a version-specific generator.
