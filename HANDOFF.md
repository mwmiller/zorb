# Handoff - Zorb

Zorb is a high-performance, idiomatic WebAssembly Z-machine interpreter built using Elixir and the Orb DSL. It aims to provide a fast and secure environment for running interactive fiction on the web or any WASM-compatible runtime.

## Current State

- **Runtime**: Uses `wasmex` (~> 0.14.0) for executing WebAssembly modules.
- **Architecture**: Uses a prime number of memory pages (13) and semantic custom WASM types (`T.Address`, `T.Object`, etc.).
- **Robustness**: Implemented write-guards for static memory, stack overflow checks, and a `zio.halt` fatal error interface.
- **Performance**: Version-specific offsets and packed address shifts are cached in global variables during initialization. Dictionary lookups use an efficient binary search. Fast `load_story` bulk copy implemented.
- **I/O & Opcodes**:
  - Implemented `read`, `print_num`, `read_char`, `print_char`, `print_obj`, `print_zstring`, `print_unicode`, `check_unicode`, `set_font`.
  - Implemented `test_attr`, `set_attr`, `clear_attr`, `test`, `get_prop_addr`.
  - Robust opcode dispatch distinguishing VAR vs 2OP-VAR forms and handling extended opcodes.
  - ZSCII handling for input and output, including Unicode support and Font 3 mapping.
  - **Standalone**: Font state and character mapping are handled *entirely* within the WASM module (`Zorb.Interpreter`), reducing host dependency.
- **Spec**: `ZMACHINE_SPEC.md` updated with I/O, opcode tables, and Unicode/Font 3 details.

## Recent Accomplishments

- **Font 3 (Graphics)**: Implemented `set_font` (EXT:4) and character mapping for Runes/Graphics in `Zorb.Interpreter`.
  - Expanded mapping to include box-drawing characters based on "best-guess" bitmap analysis.
  - Annotated source code with confidence levels (High/Medium/Low).
  - Used Elixir unquoting and Macro escaping to generate efficient WASM branch logic.
- **Unicode**: Implemented `print_unicode` (EXT:11) and `check_unicode` (EXT:12) internally in WASM.
- **Wasmex Migration**: Replaced `orb_wasmtime` with `wasmex`.

## Known Issues

- **zio.halt Interface**: All tests now include a mock for `halt` that returns `0`.
- **Input Timing**: `read_char` and `read` do not yet support timed input (V4+ feature).

## Next Steps

1.  **Advanced Opcodes**: Implement `random`, `scan_table`, and `verify`.
2.  **Serialization**: Implement `save` and `restore` opcodes for state persistence.
3.  **Loader Utility**: Create a utility to load and initialize the interpreter with `.z3` and `.z5` story files.
4.  **Screen Model**: Implement `split_window`, `set_window`, etc. for V3 status line and V4+ screen features.

## Technical Notes

- **Orb DSL**: Be careful with `I32.match` in complex blocks; prefer `if` statements with `return()` for stability.
- **Memory Layout**: Ensure the stack is properly initialized at the provided offset during `init/1`.
- **Z-machine Versions**: Currently optimized for V3-V5; V8 support is partially implemented via `@packed_address_shift`.
- **Wasmex**: Callbacks receive arguments as a single value (if 1 arg) or list. `TestRuntime` wrapper normalizes this to a list for `apply/2`. Memory operations require passing the `store`.
- **Font 3**: Mapped to Unicode approximates internally in `Zorb.Interpreter`. 
  - **Runes (97-122)**: High confidence.
  - **Arrows (!, ", ^)**: High confidence.
  - **Lines (-, |, etc)**: Medium confidence.
  - **Corners ({, }, ~)**: Low confidence.