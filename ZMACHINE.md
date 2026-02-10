# Z-Machine Specification, Implementation & Tracing

This document consolidates the Z-machine specification (V1-V8) with critical implementation details, edge cases, and debugging patterns discovered during the development of Zorb.

## 1. Memory and Architecture
- **Version Scope**: Zorb supports Versions 1-5 and 7-8. **Version 6 is explicitly out of scope**.
- **Memory Map**: 
  - **Dynamic**: `0x0000` to `Static Base - 1` (Read/Write).
  - **Static**: `Static Base` to `High Base - 1` (Read-only for Z-code).
  - **High**: `High Base` to end of file (Read-only, contains code/strings).
- **Numbers**: 16-bit signed integers (-32768 to 32767). All arithmetic is 16-bit bitwise.
- **Initial PC**: Found at header offset `0x06`. 
  - **V1-5, 7-8**: Byte address.
  - **V6**: Packed routine address (Spec 11.1.3).

## 2. Variables and the Stack (Spec 14.3)
Proper handling of **Variable 0 (SP)** is critical.

### The Two Modes of SP Access
1.  **Direct Access (Operand Type 10, value 0)**:
    -   **Read**: Pop value from stack.
    -   **Write**: Push value onto stack.
2.  **Indirect Access (Variable Reference)**:
    -   Opcodes: `load`, `store`, `inc`, `dec`, `inc_chk`, `dec_chk`, `pull`.
    -   **Read (Peek)**: Read top of stack **without popping**.
    -   **Write (Replace)**: **Replace** the top of stack (do not push).

## 3. Instruction Dispatch
- **Opcode Identification**: Opcode number + operand count (0OP, 1OP, 2OP, VAR) identifies the instruction.
- **Opcode Form**: Determined by top two bits:
  - `10`: **Short form** (1OP or 0OP).
  - `00` or `01`: **Long form** (Always 2OP).
  - `11`: **Variable form** (VAR or 2OP).
  - `0xBE`: **Extended form** (EXT).
- **je (2OP:1)**: In Variable form, it can take up to 4 operands. Jumps if the first matches *any* other.

## 4. Subroutines and Call Frames
- **Standard Frame (5 words in Zorb)**:
  1.  **Return PC Low**
  2.  **Return PC High**
  3.  **Result Variable** (bits 0-7) | **Arg Count** (bits 8-15)
  4.  **Old FP**
  5.  **Old SP** (Essential for stack restoration)
- **Locals**: In V3, defaults are read from Z-code; in V4+, they are initialized to 0.

## 5. The Object Table
- **V3**: 9-byte entries. 31 default properties.
- **V4+**: 14-byte entries. 63 default properties.
- **Property Headers**: V4+ uses bit 7 to signal a 2-byte header.

## 6. Text and ZSCII
- **Alphabets**: A0, A1, A2.
  - **V1-2**: Relative shifts/locks (Spec 3.5.4).
  - **V3+**: Fixed shifts (Spec 3.5.3).
- **Font 3**: Maps ZSCII 33–126 to character graphics (box drawings and runes).

## 7. Tracing and Debugging

### Instruction-Level Tracing
Use the `log_step` Host import to see every opcode execution.

```elixir
# In Runner.ex
fn _ctx, tick, pc, opcode ->
  IO.puts(:stderr, "Zorb: Step #{tick}: PC=0x#{Integer.to_string(pc, 16)} Op=0x#{Integer.to_string(opcode, 16)}")
end
```

### Identifying Infinite Loops
Use prime-numbered sampling (e.g., every 719 steps) to detect patterns without syncing with the loop period.

### Cache Management
When modifying the interpreter logic, clear the cache to ensure changes are reflected:
```bash
rm -rf tmp/zorb_cache/*
```

## External Specification Links
- [Standard 1.1 Specification](https://zspec.jaredreisinger.com/)
