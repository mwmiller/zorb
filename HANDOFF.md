# Handoff - Zorb

Zorb is a high-performance, idiomatic WebAssembly Z-machine interpreter built using Elixir and the Orb DSL. It aims to provide a fast and secure environment for running interactive fiction on the web or any WASM-compatible runtime.

## Current State

- **Architecture**: Uses a prime number of memory pages (13) and semantic custom WASM types (`T.Address`, `T.Object`, etc.).
- **Performance**: Version-specific offsets and packed address shifts are cached in global variables during initialization. Dictionary lookups use an efficient binary search.
- **Opcode Support**:
    - Core arithmetic, logic, and branching.
    - Full object tree management (`insert_obj`, `remove_obj`, property access).
    - Routine calls (V3 and V4+) and stack management.
    - Z-string decoding with support for abbreviations.
    - Dictionary tokenization (`tokenise`).

## Recent Accomplishments

- **Performance Refactoring**: Cached object table start, entry sizes, and parent/sibling/child offsets in globals to minimize runtime branching.
- **Binary Search**: Replaced linear dictionary lookup with binary search, significantly improving `tokenise` performance.
- **Orb Stability**: Standardized the use of `I32.const()` in complex blocks and ensured explicit `return()` paths to avoid WASM translation errors.
- **Idiomatic Code**: Eliminated Elixir-level `if` expressions in favor of pattern matching and guards, adhering to project style guidelines.

## Next Steps

1.  **Host I/O**: Implement `read` and `print` opcodes by connecting to the `zio` host imports.
2.  **Advanced Opcodes**: Implement `random`, `scan_table`, and `verify`.
3.  **Serialization**: Implement `save` and `restore` opcodes for state persistence.
4.  **Loader Utility**: Create a utility to load and initialize the interpreter with `.z3` and `.z5` story files.

## Technical Notes

- **Orb DSL**: Be careful with `I32.match` in complex blocks; prefer `if` statements with `return()` for stability.
- **Memory Layout**: Ensure the stack is properly initialized at the provided offset during `init/1`.
- **Z-machine Versions**: Currently optimized for V3-V5; V8 support is partially implemented via `@packed_address_shift`.
