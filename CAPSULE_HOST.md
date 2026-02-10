# Zorb Capsule Host Interface

A Zorb Game Capsule is a standalone WASM binary that implements the Z-machine logic. It acts as a black box that communicates with a host environment (the "Host") via WASM imports in the `zio` namespace.

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

### `tokenize(text_addr: i32, parse_addr: i32, dict_addr: i32, flag: i32)`
Performs lexical analysis on a text buffer and writes the results to a parse buffer. This is an optional host import that can be used to offload tokenization from WASM to the host (e.g., for performance or to use a more complex tokenizer).

#### Implementation Details:
1.  **Read Version**: The Z-machine version is at byte address `0x00` in WASM memory.
2.  **Read Text**: The text buffer format depends on the version:
    -   **V1-4**: `max_length` at byte 0, followed by `\0`-terminated ZSCII text.
    -   **V5+**: `max_length` at byte 0, `actual_length` at byte 1, followed by ZSCII text.
3.  **Read Dictionary**: The dictionary contains a list of separators and entry information.
4.  **Tokenize**: Split the text by separators and spaces.
5.  **Lookup**: For each word, encode it into Z-characters (6 for V1-3, 9 for V4+) and find its address in the dictionary.
6.  **Write Parse Buffer**:
    -   Byte 0: Maximum number of words (read from buffer).
    -   Byte 1: Number of words found (written by tokenizer).
    -   Subsequent 4-byte entries: `[dict_addr:16 (big-endian), word_len:8, word_offset:8]`.

#### Elixir Usage:
In `Zorb.Runner`, the `tokenize` import is mapped to `&Zorb.Tokeniser.tokenize/5`. This implementation reads WASM memory, performs the analysis in Elixir, and writes the results back to WASM memory.

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