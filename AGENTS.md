# Zorb Agent Handbook

## Project Status
Zorb is a WebAssembly Z-machine interpreter built using Elixir and the Orb DSL.

### Implemented Features
- **Core Architecture**: Stack management (FP/SP), Global variables, Memory paging (13 pages, 832KB).
- **Runtime**: Uses `wasmex` for high-performance WebAssembly execution.
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
- **I/O & Text**:
  - Opcodes: `read`, `print_num`, `read_char`, `print_char`, `print_obj`, `print_zstring`, `new_line`.
  - **Unicode**: Internal `print_unicode` and `check_unicode` (EXT:11, EXT:12) support.
  - **Font 3 (Graphics)**: Internal mapping for Runes and character graphics via `set_font` (EXT:4).
- **Object Table**:
  - V3 layout support (1-byte parent/sibling/child).
  - V4+ layout support (2-byte parent/sibling/child, multi-byte properties).
  - Navigation: `get_parent`, `get_child`, `get_sibling`.
  - Manipulation: `insert_obj`, `remove_obj`.
- **Properties & Attributes**:
  - Properties: `get_prop`, `put_prop`, `get_next_prop`, `get_prop_len`, `get_prop_addr`.
  - Attributes: `set_attr`, `clear_attr`, `test_attr`.
  - Other: `test` (2OP:7 bitmap comparison).
- **Tokenization**:
  - Dictionary-based lookup with Z-word encoding.
  - `tokenise` opcode supporting V1-4 and V5+ buffer formats.
  - Separator handling from dictionary.
- **Execution**:
  - `Zorb.Runner` for loading and executing `.z3` files with terminal I/O.

### Remaining Tasks
- [ ] **Advanced Opcodes**: `random`, `scan_table`, `verify`, `save`/`restore`.
- [ ] **Missing 2OP Opcodes**: `dec_chk`, `inc_chk`, `jin`.
- [ ] **V5+ Features**: Expanded alphabet tables and header extension table.
- [ ] **Screen Model**: Implement `split_window`, `set_window`, and cursor management for V3+ status lines.
- [ ] **Timed Input**: Support for timeouts in `read` and `read_char`.

## Development Guidelines
- **No `if` Expressions**: Use `case` or pattern matching with guards in Elixir code.
- **Orb Stability**: Complex nested `if` blocks in `defw` can cause translation errors. Use `return()` early or refactor into smaller helper functions.
- **Explicit Types**: Always use `I32.const()` for literals in complex expressions to avoid Orb type inference issues.
- **Testing**: Test against real interaction patterns. Use `OrbWasmtime` for execution and verify memory/state directly.
