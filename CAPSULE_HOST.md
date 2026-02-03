# Zorb Capsule Host Interface

A Zorb Game Capsule is a standalone WASM binary that implements the Z-machine logic. To function, it requires a host environment (the "Host") to provide specific I/O and system capabilities via WASM imports in the `zio` namespace.

## Required Interface

The Host **must** provide the following functions:

### `print_char(char: i32)`
Outputs a single ZSCII/Unicode character to the user's display.

### `read_char() -> i32`
Waits for a single character input from the user and returns its ZSCII value.

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

### `tokenize(text_addr: i32, parse_addr: i32, dict_addr: i32, flag: i32)`
If the host provides an optimized tokenizer, the Capsule can delegate Z-machine dictionary lookups here. (Currently required by Zorb logic).

## Memory Layout

The Host should be aware of the following fixed memory locations in the Capsule:
- `0x00000`: Raw Z-story data.
- `0x80000`: Unicode Translation Table (if applicable).
- `0x81000`: Alphabet Tables.
- `0x90000`: Z-stack.
- `0x98000`: Call Stack.
