# Zorb Usage Rules

Zorb is a Z-machine implementation that compiles story files into optimized WebAssembly "Game Capsules".

## Core Mandates

- **Versions**: Supports Z-machine Versions 1-5 and 7-8. **Version 6 is explicitly out of scope.**
- **Static Memory**: Static memory (at and above `@static_memory_base`) is read-only for the game. Any attempt to write to it must result in a halt with reason 4.
- **Variable 0 (SP)**: Follow Spec 14.3. Direct access (push/pop) vs. Indirect access (peek/replace).
- **No Side Effects**: The Game Capsule must not have its own I/O or state outside of WASM linear memory and the provided `zio` host imports.

## Architecture: The Baking Factory

Zorb uses a "Baking Factory" approach where stories are transformed into bespoke WASM binaries.

- **Sidecar Payload**: Large story data is serialized into binary files at Elixir compile-time and loaded into WASM memory via `Orb.Memory.initial_data!(offset, u8: list)`. This prevents Elixir compiler hangs on large literals.
- **Bespoke Modules**: Each story gets its own generated Elixir module that contains the optimized WASM logic for that specific story version.

## Host Interface (`zio` namespace)

The Game Capsule requires the following host imports in the `zio` namespace:

### Required Functions
- `print_char(char: i32)`: Output a ZSCII/Unicode character.
- `print_num(num: i32)`: Output a signed 32-bit integer.
- `read_char() -> i32`: Block for a single character input.
- `get_random(max: i32) -> i32`: Return a random integer [1, max].
- `get_random_seed() -> i32`: Return a 32-bit PRNG seed.
- `halt(reason: i32, pc: i32, opcode: i32)`: Signal a fatal error or quit.
    - Reason 0: Normal Quit
    - Reason 1: Stack Overflow
    - Reason 2: Stack Underflow
    - Reason 3: Illegal Opcode
    - Reason 4: Static Memory Violation

### Optional Screen Model (V3-V8)
- `set_window(window_id: i32)`
- `split_window(lines: i32)`
- `set_cursor(line: i32, col: i32)`
- `erase_window(window_id: i32)`
- `erase_line(value: i32)`
- `set_text_style(style: i32)`
- `get_screen_size() -> i32` (Packed: `[height:16, width:16]`)

## Memory Layout (Internal)

- `0x00000`: Story Memory (Header, Dynamic, Static, Z-code)
- `0x80000`: Unicode Translation Table
- `0x81000`: Alphabet Tables
- `0x82000`: Dictionary Hash Table (O(1) lookups)
- `0x90000`: Z-stack
- `0x98000`: Call Stack

## Elixir Integration

### Running a Session
Use `Zorb.run/2` for interactive sessions. It returns a `GenServer` PID.
```elixir
{:ok, session} = Zorb.run("story.z5", notify_to: self())
```

### Messages Sent to `notify_to`
- `{:zorb_output, char}`: Single character output.
- `{:zorb_output, {cmd, ...}}`: Screen model command (e.g., `{:cursor, l, c}`).
- `{:zorb_halt, reason, pc, opcode}`: Session terminated.
