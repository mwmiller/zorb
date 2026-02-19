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

### `sound_effect(number: i32)`
Plays a sound effect.
- `1`: High-pitched bleep.
- `2`: Low-pitched bleep.
- `3+`: Story-defined sound effect ID.

### `check_interrupt() -> i32`
Polled by the WASM capsule to check for Host-triggered save/restore or undo requests. This allows the Host to signal state management operations asynchronously, even while the Z-machine is waiting for input.
- `0`: No request.
- `1`: Save.
- `2`: Restore.
- `3`: Save Undo.
- `4`: Restore Undo.

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

### `set_colour(foreground: i32, background: i32)`
Sets the text colors.
- `1`: Default
- `2`: Black
- `3`: Red
- `4`: Green
- `5`: Yellow
- `6`: Blue
- `7`: Magenta
- `8`: Cyan
- `9`: White

### `get_screen_size() -> i32`
Returns the current dimensions of the host display as a packed 32-bit integer: `[height:16, width:16]`.

## Story Metadata Interface (Orbit Radio)

All Game Capsules provide access to semantic metadata extracted during compilation. This is used by the Host to determine how to present out-of-band features like "Orbit Radio".

### `zio_get_version() -> i32`
Returns the Z-machine version of the story.

### `zio_get_serial() -> i32`
Returns the memory address of the 6-byte serial number string.

### `zio_get_command_prefix() -> i32`
Returns the ZSCII/Unicode character recommended for out-of-band commands (e.g., `/` or `~`).

### `zio_get_chat_prefix() -> i32`
Returns the address of a null-terminated string representing the recommended chat tag (e.g., `RAD`, `ORB`, `VOX`). All tags are nouns and exactly 5 characters or fewer.

### `zio_get_channel_prefix() -> i32`
Returns the address of a null-terminated string representing the recommended user label (e.g., `FOLKS`, `SOULS`, `MATES`). All labels are nouns and exactly 5 characters or fewer.

## Save/Restore Interface

The following functions are used to implement the Z-machine `save` and `restore` instructions.

### `save(pc: i32, sp: i32, fp: i32, csp: i32, random_state: i32) -> i32`
Requests the Host to save the current state.
- `pc`: Current Program Counter.
- `sp`: Current Stack Pointer (word count).
- `fp`: Current Frame Pointer (word count).
- `csp`: Current Call Stack Pointer (word count).
- `random_state`: Current PRNG state.
Returns `1` if the save was successful, `0` otherwise.

### `restore() -> i32`
Requests the Host to restore a previously saved state.
Returns `1` if a state was successfully restored, `0` otherwise.

### `get_restored_pc() -> i32`
Returns the `pc` from the last successful `restore()`.

### `get_restored_sp() -> i32`
Returns the `sp` from the last successful `restore()`.

### `get_restored_fp() -> i32`
Returns the `fp` from the last successful `restore()`.

### `get_restored_csp() -> i32`
Returns the `csp` from the last successful `restore()`.

### `get_restored_random_state() -> i32`
Returns the `random_state` from the last successful `restore()`.

## Undo Interface

The following functions are used to implement the Z-machine `save_undo` and `restore_undo` instructions (V5+).

### `save_undo(pc: i32, sp: i32, fp: i32, csp: i32, random_state: i32) -> i32`
Requests the Host to save the current state for a future undo.
Returns `1` if successful, `0` otherwise, and `-1` if not supported.

### `restore_undo() -> i32`
Requests the Host to restore the last state saved via `save_undo`.
Returns `1` if successful, `0` otherwise.

### `get_undone_pc() -> i32`
Returns the `pc` from the last successful `restore_undo()`.

### `get_undone_sp() -> i32`
Returns the `sp` from the last successful `restore_undo()`.

### `get_undone_fp() -> i32`
Returns the `fp` from the last successful `restore_undo()`.

### `get_undone_csp() -> i32`
Returns the `csp` from the last successful `restore_undo()`.

### `get_undone_random_state() -> i32`
Returns the `random_state` from the last successful `restore_undo()`.

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