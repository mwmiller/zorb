# Zorb Agent Handbook

## Project Status
Zorb is a WebAssembly Z-machine interpreter built using Elixir and the Orb DSL.

### Implemented Features
- **Core Architecture**: Stack management (FP/SP), Global variables, Memory paging (13 pages, 832KB).
- **Robustness**: 
  - **Memory Protection**: Write-guards for static memory area (code/dictionary).
  - **Stack Protection**: Bounds-checking on `@sp` to prevent overflows.
  - **Halt Interface**: `zio.halt` host import for signaling fatal errors.
- **Performance**:
  - **Global Caching**: Version-specific offsets and packed shifts cached in globals.
  - **Binary Search**: $O(\log N)$ dictionary lookup.
  - **Bulk Loading**: Fast `load_story` utility for initializing memory.
- **Instruction Decoding**: 2OP, 1OP, 0OP, and VAR (including 8-operand V4+ calls).
- **Routine Management**: Standard Z-machine calling convention with local variables and return value storage.
- **Z-Strings**: 
  - 5-bit character decoding with alphabet shifting (A0, A1, A2).
  - Standard abbreviation expansion with recursion protection (depth limit 2).
- **Object Table**:
  - V3 layout support (1-byte parent/sibling/child).
  - V4+ layout support (2-byte parent/sibling/child, multi-byte properties).
  - Navigation: `get_parent`, `get_child`, `get_sibling`.
  - Manipulation: `insert_obj`, `remove_obj`.
- **Properties**:
  - `get_prop`, `put_prop`, `get_next_prop`, `get_prop_len`.
  - Version-specific header encoding (V1-3 vs V4+).
- **Attributes**: `set_attr`, `clear_attr`, `test_attr`.
- **Tokenization**:
  - Dictionary-based lookup with Z-word encoding.
  - `tokenise` opcode supporting V1-4 and V5+ buffer formats.
  - Separator handling from dictionary.

### Remaining Tasks
- [ ] **Input/Output**: Connect `read` and `print` opcodes to real host interfaces.
- [ ] **Extended Character Sets**: Full A2 set support and Unicode conversion.
- [ ] **Advanced Opcodes**: `random`, `scan_table`, `verify`, `save`/`restore`.
- [ ] **V5+ Features**: Expanded alphabet tables and header extension table.
- [ ] **File Loading**: Utility to load actual .z3/.z5 story files into memory.

## Development Guidelines
- **No `if` Expressions**: Use `case` or pattern matching with guards in Elixir code.
- **Orb Stability**: Complex nested `if` blocks in `defw` can cause translation errors. Use `return()` early or refactor into smaller helper functions.
- **Explicit Types**: Always use `I32.const()` for literals in complex expressions to avoid Orb type inference issues.
- **Testing**: Test against real interaction patterns. Use `OrbWasmtime` for execution and verify memory/state directly.
