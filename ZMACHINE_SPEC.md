# Z-Machine Specification & Implementation Notes

This document consolidates the Z-machine specification (V3-V5) with critical implementation details and edge cases discovered during the development of Zorb.

## 1. Memory and Architecture
- **Version Scope**: Zorb supports Versions 1-5 and 7-8. **Version 6 is explicitly out of scope** due to its fundamentally different graphical and coordinate-based model.
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
- **Opcode Identification**: Opcode number alone is insufficient to identify an instruction. The **operand count** (0OP, 1OP, 2OP, VAR) must also be known, as different instructions may share the same number across different counts.
- **Opcode Form**: Determined by the top two bits of the first opcode byte:
  - `10`: **Short form** (1OP or 0OP).
  - `00` or `01`: **Long form** (Always 2OP).
  - `11`: **Variable form** (VAR or 2OP).
  - `10111110` (0xBE): **Extended form** (EXT).
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
- **Alphabets**: Three sets (A0, A1, A2). A0 is initial.
  - **Versions 1 & 2**: Characters 2 and 3 are relative single-character shifts. Characters 4 and 5 are relative shift-locks.
  - **Version 3+**: Characters 4 and 5 are fixed single-character shifts to A1 and A2 respectively.
- **Abbreviations**:
  - **Version 2**: Character 1 is the only abbreviation marker (Bank 0, 32 entries).
  - **Version 3+**: Characters 1, 2, and 3 are markers for Banks 0, 1, and 2 respectively (96 total).
- **Font 3**: Used for graphics. `set_font` (EXT:4) returns the previous font. If Font 3 is requested but unsupported, return 0.
  - **Character Graphics**: Maps ZSCII 33–126 to 8x8 bitmaps.
  - **Unicode Mapping**: Standardized to box-drawing characters and Anglian futhorc runes.
    - `!` (33) to `+` (43): Box drawings (e.g., 33=`│`, 34=`─`, 35=`┌`, 36=`┐`, 37=`└`, 38=`┘`, 39=`├`, 40=`┤`, 41=`┬`, 42=`┴`, 43=`┼`).
    - `a` (97) to `z` (122): Futhorc runes (e.g., `a` maps to `ᚪ` (0x16AA)).
    - Special mappings: `c` to `eo`, `k` to `z-sound k`, `q` to `k`, `v` to `ea`, `x` to `z`, `z` to `oe`.

## 7. Input Handling
- **sread (V1-4)**: Reads a line, converts to lowercase, stores in text buffer.
- **aread (V5+)**: Same, but returns the terminating character.
- **read_char (V4+)**: Reads a single character. Note that some provers expect this to NOT echo or wait for a newline.

## External Specification Links

### Fundamentals
- [1. The memory map](https://zspec.jaredreisinger.com/01-memory-map)
- [2. Numbers and arithmetic](https://zspec.jaredreisinger.com/02-numbers)
- [3. How text and characters are encoded](https://zspec.jaredreisinger.com/03-text)
- [4. How instructions are encoded](https://zspec.jaredreisinger.com/04-instructions)
- [5. How routines are encoded](https://zspec.jaredreisinger.com/05-routines)
- [6. The game state: storage and routine calls](https://zspec.jaredreisinger.com/06-game-state)

### Input/Output
- [7. Output streams and file handling](https://zspec.jaredreisinger.com/07-output)
- [8. The screen model](https://zspec.jaredreisinger.com/08-screen)
- [9. Sound effects](https://zspec.jaredreisinger.com/09-sound)
- [10. Input streams and devices](https://zspec.jaredreisinger.com/10-input)

### Tables
- [11. The format of the header](https://zspec.jaredreisinger.com/11-header)
- [12. The object table](https://zspec.jaredreisinger.com/12-objects)
- [13. The dictionary and lexical analysis](https://zspec.jaredreisinger.com/13-dictionary)

### Instruction Set
- [14. Complete table of opcodes](https://zspec.jaredreisinger.com/14-opcode-table)
- [15. Dictionary of opcodes](https://zspec.jaredreisinger.com/15-opcodes)

### An Unusual Font
- [16. Font 3 and character graphics](https://zspec.jaredreisinger.com/16-font3)

### Appendices
- [Appendix A. Error messages and debugging](https://zspec.jaredreisinger.com/A-errors)
- [Appendix B. Conventional contents of the header](https://zspec.jaredreisinger.com/B-conventional-header)
- [Appendix C. Resources available](https://zspec.jaredreisinger.com/C-resources)
- [Appendix D. A short history of the Z-machine](https://zspec.jaredreisinger.com/D-history)
- [Appendix E. Statistics](https://zspec.jaredreisinger.com/E-statistics)
- [Appendix F. Canonical Story Files](https://zspec.jaredreisinger.com/F-canonical-story-files)

### Meta information
- [Editor’s note](https://zspec.jaredreisinger.com/ZZ01-editors-note)
- [Conventions used in this document](https://zspec.jaredreisinger.com/ZZ02-conventions)
- [Opcodes revisited](https://zspec.jaredreisinger.com/ZZ03-opcodes)
- [Colophon](https://zspec.jaredreisinger.com/ZZ04-colophon)