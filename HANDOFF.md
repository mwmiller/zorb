# Handoff - January 28, 2026

## Current Status
Working through **CZECH** prover failures for V5 compliance. 

### Improvements & Fixes
- **Spec 14.3 Compliance**: Fully implemented "variable reference" opcode behavior for `load`, `store`, `inc`, `dec`, `inc_chk`, `dec_chk`, and `pull`. Variable 0 (SP) correctly performs peek/replace/pop as required by the specification.
- **Subroutine Frame Standardization**: Standardized the 4-word frame structure (Return PC Low/High, Store Var/Arg Mask, Old FP) and ensured consistent local variable access at `@fp + 4`.
- **V5+ Argument Masking**: Implemented bitmask-based argument tracking for subroutines, replacing simple counts to support `check_arg_count` (VAR:31).
- **WASM/Orb Robustness**: 
    - Refactored `get_arg_mask` and `count_args_from_mask` to use explicit `if/else` assignments, bypassing WASM local variable scoping limitations.
    - Ensured all 16-bit arithmetic results and variable writes are masked to 16 bits.
    - Fixed 14-bit sign extension logic in `fetch_branch`.
- **Clean Logic**: Removed `do:` blocks without `else` branches across the interpreter to prevent confounding `nil` values in Orb.
- **Reduced Debug Noise**: Removed PC and ZChar logging to clarify prover output.

### Blockers / Pending Issues
1. **ERROR [179]-[185] (check_arg_count)**: "claimed argument 1 was not given when it was."
   - The `arg_mask` stored in the frame is not matching prover expectations.
2. **ERROR [327] (Indirect Opcodes)**: "Expected 45; got 44" in `dec_chk` or `inc_chk`.
   - The value is 1-off, potentially due to subtle stack top interaction or side effects in peeking vs popping.

### Next Steps
- Add targeted logging to `do_call` to verify the generated `arg_mask`.
- Audit `dec_chk 0` and `inc_chk 0` to ensure they interact with the stack top exactly as expected (peek and replace).
- Once resolved, move to final CZECH sections and re-enable `strictz.z5`.