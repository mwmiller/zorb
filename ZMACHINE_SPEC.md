# Z-Machine Specification & Implementation Notes

This document consolidates the Z-machine specification (V3-V5) with critical implementation details and edge cases discovered during the development of Zorb.

## 1. Memory and Architecture
- **Memory Map**: 
  - **Dynamic**: `0x0000` to `Static Base - 1` (Read/Write).
  - **Static**: `Static Base` to `High Base - 1` (Read-only for Z-code).
  - **High**: `High Base` to end of file (Read-only, contains code/strings).
- **Numbers**: 16-bit signed integers (-32768 to 32767). All arithmetic is 16-bit bitwise.
- **Initial PC**: Found at header offset `0x06`. In V3, this is a byte address; in V4-V5, it is a routine address (but the header usually stores the byte address of the first instruction).

## 2. Variables and the Stack (Spec 14.3)
Proper handling of **Variable 0 (SP)** is the most common source of interpreter errors.

### The Two Modes of SP Access
1.  **Direct Access (Operand Type 10, value 0)**:
    -   **Read**: Pop value from stack.
    -   **Write**: Push value onto stack.
2.  **Indirect Access (Variable Reference)**:
    -   Opcodes: `load`, `store`, `inc`, `dec`, `inc_chk`, `dec_chk`, `pull`.
    -   **Read (Peek)**: If the operand refers to variable 0, read the top of the stack **without popping**.
    -   **Write (Replace)**: If the operand refers to variable 0, **replace** the top of the stack with the new value (do not push).
    -   **Exception (`pull`)**: In `pull (0)`, the value is pulled off the stack and then pushed back (effectively a NOP, but consumes the stack value).

## 3. Instruction Dispatch
- **je (2OP:1)**: When encoded in **Variable** form, it can take 2, 3, or 4 operands. It jumps if the first operand is equal to **any** of the subsequent operands.
- **check_arg_count (VAR:31)**: V5+ only. Returns true if the current routine was called with at least `n` arguments. Requires the argument count to be stored in the call frame.

## 4. Subroutines and Call Frames
- **Standard Frame (4 words)**:
  1.  **Return PC Low** (16 bits)
  2.  **Return PC High** (remaining bits)
  3.  **Result Variable** (bits 0-7) | **Arg Count** (bits 8-15)
  4.  **Old FP** (Frame Pointer)
- **Locals**: Follow the 4-word header. In V3, defaults are read from the Z-code; in V4+, they are initialized to 0.

## 5. The Object Table
### Version 3
- **Entry**: 9 bytes. Attributes (4), Parent (1), Sibling (1), Child (1), Prop Table Address (2).
- **Properties**: 31 defaults. Property number 1-31. Header is 1 byte: `size-1` (bits 5-7), `num` (bits 0-4).

### Version 4+
- **Entry**: 14 bytes. Attributes (6), Parent (2), Sibling (2), Child (2), Prop Table Address (2).
- **Properties**: 63 defaults. Property number 1-63.
- **Property Header**:
  - If Bit 7 is 1: 2-byte header. Size is bits 0-5 of second byte (0 means 64).
  - If Bit 7 is 0: 1-byte header. Bit 6 is size (0=1, 1=2).

## 6. Text and ZSCII
- **Abbreviations**: Always 32 entries per bank (3 banks). Abbreviations are packed addresses pointing to Z-strings.
- **Font 3**: Used for graphics. `set_font` (EXT:4) returns the previous font. If Font 3 is requested but unsupported, return 0.

## 7. Input Handling
- **sread (V1-4)**: Reads a line, converts to lowercase, stores in text buffer.
- **aread (V5+)**: Same, but returns the terminating character.
- **read_char (V4+)**: Reads a single character. Note that some provers expect this to NOT echo or wait for a newline.