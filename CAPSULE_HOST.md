# Zorb Capsule Host Interface

A Zorb Game Capsule is a standalone WASM binary that implements the Z-machine logic. It acts as a black box that communicates with a host environment (the "Host") via WASM imports in the `zio` namespace.

## Required Interface

The Host **must** provide the following functions:

### `print_char(char: i32)`
Outputs a single ZSCII/Unicode character to the user's display.

### `print_num(num: i32)`
Outputs a signed 32-bit integer to the user's display.

### `read_char() -> i32`
Waits for a single character input from the user and returns its ZSCII value.

### `get_random(max: i32) -> i32`
Returns a random integer between 1 and `max` (inclusive). If `max` is negative or zero, it may reset the PRNG state.

### `get_random_seed() -> i32`
Returns a 32-bit integer to seed the Z-machine's internal PRNG.

### `halt(reason: i32, pc: i32, opcode: i32)`
Called when the Z-machine encounters a fatal error or a `quit` instruction. 
Reasons include:
- `0`: Normal exit (`quit`)
- `1`: Stack overflow
- `2`: Stack underflow
- `3`: Illegal opcode
- `4`: Static memory violation

### `log_step(tick: i32, pc: i32, opcode: i32)`
Optional import for instruction-level tracing. Called before each opcode execution.

## Screen Model Interface (V3-V8)

The following functions are used to implement the Z-machine screen model (Spec 8). If the Host signals support via `get_capabilities`, it **must** provide these:

### `set_window(window_id: i32)`
Directs subsequent output and cursor operations to the specified window.
- `0`: Lower window (scrolling).
- `1`: Upper window (non-scrolling).

### `split_window(lines: i32)`
Splits the screen so that Window 1 occupies the top `lines` of the display. If `lines` is 0, Window 1 is collapsed. In a CLI, this typically reserves the top N lines for a fixed status display.

### `set_cursor(line: i32, col: i32)`
Moves the cursor to the specified coordinates within the currently selected window. Coordinates are 1-indexed.

### `erase_window(window_id: i32)`
Clears the specified window. If `window_id` is `-1`, the entire screen is cleared and all windows are reset.

### `erase_line(value: i32)`
Erases from the current cursor position to the end of the line.

### `set_text_style(style: i32)`
Sets the text rendering style. Styles are bit-mapped:
- `0`: Roman (Normal)
- `1`: Reverse Video
- `2`: Bold
- `4`: Italic
- `8`: Fixed-pitch

### `get_screen_size() -> i32`
Returns the current dimensions of the host display as a packed 32-bit integer: `[height:16, width:16]`.

## Optional Interface (Capabilities)

The Host can signal support for optional features. The Capsule checks these via the following host import:

### `get_capabilities() -> i32`
Returns a bitmask of supported features.
- `Bit 0 (0x01)`: Status line available.
- `Bit 1 (0x02)`: Screen splitting available.
- `Bit 2 (0x04)`: Variable-width font available.
- `Bit 3 (0x08)`: Font 3 (Character Graphics) available.
- `Bit 4 (0x10)`: Color available.
- `Bit 5 (0x20)`: Timed input available.

## Appendix: Internal Memory Layout

The following memory locations are used internally by the Capsule. The Host is **not required** to access these, but they are documented for transparency and debugging.

- `0x00000`: Story Memory (Header, Dynamic Memory, Static Data, Z-code).
- `0x80000`: Unicode Translation Table.
- `0x81000`: Alphabet Tables.
- `0x82000`: Dictionary Hash Table (O(1) lookups).
- `0x90000`: Z-stack.
- `0x98000`: Call Stack.