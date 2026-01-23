# Z-Machine Specification Summary (V3-V8)

This document provides a concise reference for Z-machine interpreter implementation. It is based on the [Z-Machine Standards Document](https://zspec.jaredreisinger.com/).

> **Note**: As specific sections of the Z-machine specification are consumed during development, their contents should be summarized and imported here for future reference to maintain a self-contained project context.

## 1. Memory Map
Refer to [1. The memory map](https://zspec.jaredreisinger.com/01-memory-map) for details.
- **Dynamic Memory**: `0x0000` to `Static Base - 1`. Read/Write.
- **Static Memory**: `Static Base` to `High Base - 1`. Read-only for Z-code (interpreter may write).
- **High Memory**: `High Base` to end of file. Read-only.

## 2. Header Offsets
Refer to [11. The format of the header](https://zspec.jaredreisinger.com/11-header) for full details.

| Offset | Size | Description |
| :--- | :--- | :--- |
| `0x00` | 1 | Version (1-8) |
| `0x01` | 1 | Flags 1 |
| `0x02` | 2 | Release number |
| `0x04` | 2 | High memory base |
| `0x06` | 2 | Initial Program Counter (PC) |
| `0x08` | 2 | Dictionary base |
| `0x0A` | 2 | Object table base |
| `0x0C` | 2 | Globals table base |
| `0x0E` | 2 | Static memory base |
| `0x10` | 2 | Flags 2 |
| `0x18` | 2 | Abbreviations table base |
| `0x1A` | 2 | Length of file (units vary by version) |
| `0x1C` | 2 | Checksum |

## 3. Instruction Encoding
Refer to [4. How instructions are encoded](https://zspec.jaredreisinger.com/04-instructions) and [14. Complete table of opcodes](https://zspec.jaredreisinger.com/14-opcode-table) for full details.

### Opcode Forms
- **Short**: `10 | Type(2 bits) | Opcode(4 bits)`
  - Types: `00`=Large (2 bytes), `01`=Small (1 byte), `10`=Variable (1 byte), `11`=0 operands.
- **Long**: `0 | Type1(1 bit) | Type2(1 bit) | Opcode(5 bits)` (2OP)
  - Types: `0`=Small, `1`=Variable.
- **Variable**: `11 | TypeIndicator(1 bit) | Opcode(5 bits)`
  - Followed by 1 or 2 `Types` bytes (2 bits per operand).
  - TypeIndicator: `0`=2OP, `1`=VAR.
- **Extended**: Opcode `0xBE`, followed by 1 byte opcode and types byte.

### Operand Types
- `00`: Large Constant (2 bytes)
- `01`: Small Constant (1 byte)
- `10`: Variable (1 byte: 0=stack, 1-15=local, 16-255=global)
- `11`: Omitted

## 4. Object Table
Refer to [12. The object table](https://zspec.jaredreisinger.com/12-objects) for full details.

### Version 1-3
- **Entry Size**: 9 bytes.
- **Layout**:
  - Attributes: 4 bytes (32 bits).
  - Parent, Sibling, Child: 1 byte each.
  - Property Table Address: 2 bytes.
- **Property Defaults**: 31 words at table base.

### Version 4+
- **Entry Size**: 14 bytes.
- **Layout**:
  - Attributes: 6 bytes (48 bits).
  - Parent, Sibling, Child: 2 bytes each.
  - Property Table Address: 2 bytes.
- **Property Defaults**: 63 words at table base.

## 5. Property Tables
Properties are stored in descending numerical order. A property table is terminated by a zero byte.
- **Version 1-3**:
  - Each property starts with a size byte: bits 0-4 are property number (1-31), bits 5-7 are size-1.
  - Data follows: 1 byte for size 1, 2 bytes for size 2-64.
- **Version 4+**:
  - First byte: bits 0-5 are property number (1-63). Bit 7 indicates if a second size byte follows.
  - If bit 7 is 1: second size byte follows (bits 0-5 are size; 0 means 64). Data size is 2 bytes.
  - If bit 7 is 0: bit 6 indicates size (0=1 byte, 1=2 bytes). Data size is 1 or 2 bytes.

## 6. Z-Strings
Refer to [3. How text and characters are encoded](https://zspec.jaredreisinger.com/03-text) for full details.

- **Format**: 16-bit words. Bit 15=1 (End), bits 14:10, 9:5, 4:0 are 5-bit Z-chars.
- **Alphabets**:
  - **A0**: `abcdefghijklmnopqrstuvwxyz`
  - **A1**: `ABCDEFGHIJKLMNOPQRSTUVWXYZ`
  - **A2**: ` \n^0123456789.,!?_#'"\-:()` (varies)
- **Special Z-chars**:
  - `0`: Space
  - `1-3`: Abbreviations (next Z-char is index). Abbreviation table entries are packed addresses.
  - `4`: Shift to A1 (for 1 char) or permanent shift (V1-2).
  - **Note on permanent shift (V1-2)**: Not implemented.
  - `5`: Shift to A2.
  - `6` (in A2): 10-bit ZSCII follows (2 Z-chars).

## 7. Dictionary
Refer to [13. The dictionary and lexical analysis](https://zspec.jaredreisinger.com/13-dictionary) for full details.

- **Structure**:
  - `n` (1 byte): Number of word separators.
  - `sep1...sepN` (n bytes): Separator characters.
  - `entry_len` (1 byte): Length of each dictionary entry in bytes.
  - `num_entries` (2 bytes): Number of entries.
  - `entries`: Sorted table of `num_entries` entries. Each entry consists of the Z-character representation of the word, followed by its corresponding object number. Entries are variable length based on `entry_len`. Dictionary lookups typically use binary search.

## 8. Calling Convention
Refer to [6. The game state: storage and routine calls](https://zspec.jaredreisinger.com/06-game-state) for details.

- **Call**: Routine address (packed), followed by operands (initial values for locals).
- **Routine Header**: 1 byte `locals_count`.
- **V1-3**: Routine header also contains initial values for locals (2 bytes each).
- **Stack Frame**: PC (return address), result variable, old FP, locals.
