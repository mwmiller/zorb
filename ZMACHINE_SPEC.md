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
| `0x2E` | 2 | Terminating characters table (V5+) |
| `0x34` | 2 | Alphabet table address (V5+, 0=default) |
| `0x36` | 2 | Header extension table address (V5+) |

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

## 6. Z-Strings and Characters
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
  - `5`: Shift to A2.
  - `6` (in A2): 10-bit ZSCII follows (2 Z-chars).

### ZSCII and Unicode
- **ZSCII 0-31**: Undefined/Control (except 13=Newline).
- **ZSCII 32-126**: Standard ASCII.
- **ZSCII 127-154**: Input codes (cursor keys, F-keys, keypad).
- **ZSCII 155-251**: Extra characters (Unicode table).
- **ZSCII 252-254**: Mouse clicks (V6).

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

## 9. Input/Output (Input Streams and Devices)
Refer to [10. Input streams and devices](https://zspec.jaredreisinger.com/10-input) for details.

- **Input Streams**:
  - 0: Keyboard.
  - 1: File containing commands.
- **Read Operation**:
  - `read` (or `sread` in V1-4, `aread` in V5+): Reads whole commands.
  - **Terminators**: New-line (default). V5+ can provide a "terminating characters table".
- **Single Keypress**:
  - `read_char` (V4+): Reads individual ZSCII characters.

## 10. Opcodes
Refer to [14. Complete table of opcodes](https://zspec.jaredreisinger.com/14-opcode-table) for full details.

### 2OP (Two-operand)
| Opcode | Hex | V | Name | Notes |
| :--- | :--- | :--- | :--- | :--- |
| 1 | 01 | | je a b ?(label) | Jump if equal |
| 2 | 02 | | jl a b ?(label) | Jump if less |
| 3 | 03 | | jg a b ?(label) | Jump if greater |
| 4 | 04 | | dec_chk (variable) value ?(label) | Dec var and branch if < value |
| 5 | 05 | | inc_chk (variable) value ?(label) | Inc var and branch if > value |
| 6 | 06 | | jin obj1 obj2 ?(label) | Jump if obj1 in obj2 |
| 7 | 07 | | test bitmap flags ?(label) | Jump if (bitmap & flags) == flags |
| 8 | 08 | | or a b -> (result) | Bitwise OR |
| 9 | 09 | | and a b -> (result) | Bitwise AND |
| 10 | 0A | | test_attr object attribute ?(label) | Jump if object has attribute |
| 11 | 0B | | set_attr object attribute | Set attribute |
| 12 | 0C | | clear_attr object attribute | Clear attribute |
| 13 | 0D | | store (variable) value | Store value in variable |
| 14 | 0E | | insert_obj object destination | Move object to destination |
| 15 | 0F | | loadw array word-index -> (result) | Load word from array |
| 16 | 10 | | loadb array byte-index -> (result) | Load byte from array |
| 17 | 11 | | get_prop object property -> (result) | Get property data |
| 18 | 12 | | get_prop_addr object property -> (result) | Get property address |
| 19 | 13 | | get_next_prop object property -> (result) | Get next property number |
| 20 | 14 | | add a b -> (result) | Addition |
| 21 | 15 | | sub a b -> (result) | Subtraction |
| 22 | 16 | | mul a b -> (result) | Multiplication |
| 23 | 17 | | div a b -> (result) | Division |
| 24 | 18 | | mod a b -> (result) | Remainder |
| 25 | 19 | 4 | call_2s routine arg1 -> (result) | Call routine |
| 26 | 1A | 5 | call_2n routine arg1 | Call routine (no result) |
| 27 | 1B | 5 | set_colour fg bg | Set colors |
| 28 | 1C | 5 | throw value stack-frame | Throw exception |

### 1OP (One-operand)
| Opcode | Hex | V | Name | Notes |
| :--- | :--- | :--- | :--- | :--- |
| 128 | 00 | | jz a ?(label) | Jump if zero |
| 129 | 01 | | get_sibling object -> (result) ?(label) | Get sibling and branch if exists |
| 130 | 02 | | get_child object -> (result) ?(label) | Get child and branch if exists |
| 131 | 03 | | get_parent object -> (result) | Get parent |
| 132 | 04 | | get_prop_len property-address -> (result) | Get property length |
| 133 | 05 | | inc (variable) | Increment variable |
| 134 | 06 | | dec (variable) | Decrement variable |
| 135 | 07 | | print_addr byte-address-of-string | Print string at address |
| 136 | 08 | 4 | call_1s routine -> (result) | Call routine |
| 137 | 09 | | remove_obj object | Detach object from tree |
| 138 | 0A | | print_obj object | Print object name |
| 139 | 0B | | ret value | Return from routine |
| 140 | 0C | | jump ?(label) | Unconditional jump |
| 141 | 0D | | print_paddr packed-address-of-string | Print string at packed address |
| 142 | 0E | | load (variable) -> (result) | Load variable value |
| 143 | 0F | 1/4 | not value -> (result) | Bitwise NOT (V1-4), Call (V5 call_1n) |

### 0OP (Zero-operand)
| Opcode | Hex | V | Name | Notes |
| :--- | :--- | :--- | :--- | :--- |
| 176 | 00 | | rtrue | Return true (1) |
| 177 | 01 | | rfalse | Return false (0) |
| 178 | 02 | | print (literal-string) | Print literal string |
| 179 | 03 | | print_ret (literal-string) | Print literal string and return true |
| 180 | 04 | | nop | No operation |
| 181 | 05 | 1 | save ?(label) | Save state (V1-3: branch, V4: -> result) |
| 182 | 06 | 1 | restore ?(label) | Restore state (V1-3: branch, V4: -> result) |
| 183 | 07 | | restart | Restart game |
| 184 | 08 | | ret_popped | Return value from stack |
| 185 | 09 | 1 | pop | Pop stack (V5/6: catch -> result) |
| 186 | 0A | | quit | Quit game |
| 187 | 0B | | new_line | Print new line |
| 188 | 0C | 3 | show_status | Show status line |
| 189 | 0D | 3 | verify ?(label) | Verify story file |
| 190 | 0E | 5 | extended opcode | First byte of extended opcode |

### VAR (Variable-operand)
| Opcode | Hex | V | Name | Notes |
| :--- | :--- | :--- | :--- | :--- |
| 224 | 00 | 1 | call routine ... -> (result) | Call routine (V1: call, V4: call_vs) |
| 225 | 01 | | storew array word-index value | Store word in array |
| 226 | 02 | | storeb array byte-index value | Store byte in array |
| 227 | 03 | | put_prop object property value | Set property value |
| 228 | 04 | 1 | sread text parse | Read input (V5: aread -> result) |
| 229 | 05 | | print_char output-character-code | Print character |
| 230 | 06 | | print_num value | Print number |
| 231 | 07 | | random range -> (result) | Generate random number |
| 232 | 08 | | push value | Push to stack |
| 233 | 09 | 1 | pull (variable) | Pull from stack (V6: pull stack -> result) |
| 234 | 0A | 3 | split_window lines | Split screen |
| 235 | 0B | 3 | set_window window | Set current window |
| 236 | 0C | 4 | call_vs2 routine ... -> (result) | Call routine (up to 7 args) |
| 237 | 0D | 4 | erase_window window | Clear window |
| 238 | 0E | 4 | erase_line value | Clear line |
| 239 | 0F | 4 | set_cursor line column | Set cursor position |
| 240 | 10 | 4 | get_cursor array | Get cursor position |
| 241 | 11 | 4 | set_text_style style | Set text style |
| 242 | 12 | 4 | buffer_mode flag | Set buffer mode |
| 243 | 13 | 3 | output_stream number | Select output stream |
| 244 | 14 | 3 | input_stream number | Select input stream |
| 245 | 15 | 5/3 | sound_effect number ... | Play sound |
| 246 | 16 | 4 | read_char 1 time routine -> (result) | Read single char |
| 247 | 17 | 4 | scan_table x table len form -> (result) | Scan table |
| 248 | 18 | 5 | not value -> (result) | Bitwise NOT |
| 249 | 19 | 5 | call_vn routine ... | Call routine (no result) |
| 250 | 1A | 5 | call_vn2 routine ... | Call routine (no result, up to 7 args) |
| 251 | 1B | 5 | tokenise text parse dict flag | Tokenise text |
| 252 | 1C | 5 | encode_text zscii ... | Encode text |
| 253 | 1D | 5 | copy_table first second size | Copy table |
| 254 | 1E | 5 | print_table zscii width height skip | Print table |
| 255 | 1F | 5 | check_arg_count argument-number | Check argument count |

### EXT (Extended)
| Opcode | Hex | V | Name | Notes |
| :--- | :--- | :--- | :--- | :--- |
| 0 | 00 | 5 | save table bytes name -> (result) | Save |
| 1 | 01 | 5 | restore table bytes name -> (result) | Restore |
| 2 | 02 | 5 | log_shift number places -> (result) | Logical shift |
| 3 | 03 | 5 | art_shift number places -> (result) | Arithmetic shift |
| 4 | 04 | 5 | set_font font -> (result) | Set font |
| 9 | 09 | 5 | save_undo -> (result) | Save undo |
| 10 | 0A | 5 | restore_undo -> (result) | Restore undo |
| 11 | 0B | 5 | print_unicode char-number | Print Unicode char |
| 12 | 0C | 5 | check_unicode char-number -> (result) | Check Unicode support |

## 11. Font 3 and Character Graphics
Refer to [16. Font 3 and character graphics](https://zspec.jaredreisinger.com/16-font3) for full details.

- **Font 3**: Fixed-pitch, "runic" + character graphics font.
- **Mapping**: Overrides standard ASCII (32-126) when active.
- **Usage**: Set using `set_font` (EXT:4).
- **Return**: `set_font` returns `0` if font not available, otherwise previous font number.

### Character Mapping (Subset/Approximation)
This mapping converts Font 3 specific characters to unique Unicode approximations where possible (Runes/Shapes).

- `a-z` (97-122): Runic Alphabet (Anglo-Saxon/Futhorc). [High Confidence]
- `^` (94): Up-Down Arrow (↕) [High]
- `_` (95): Small Box (▫) [High]
- `!` (33): Arrow Right (→) [High]
- `"` (34): Arrow Left (←) [High]
- `#` (35): Diagonal Up (╱) [High]
- `$` (36): Diagonal Down (╲) [High]
- `%` (37): Solid Block (█) [High]
- `&` (38): Bottom Block (▄) [High]
- `'` (39): Top Block (▀) [High]
- `(` (40): Left Side Block (▌) [High]
- `)` (41): Right Side Block (▐) [High]
- `*` (42): North Connector (┴) [Medium]
- `+` (43): South Connector (┬) [Medium]
- `,` (44): East Connector (├) [Medium]
- `-` (45): West Connector (┤) [Medium]
- `.` (46): Bottom-Left Corner (└) [High]
- `/` (47): Top-Left Corner (┌) [High]
- `0` (48): Top-Right Corner (┐) [High]
- `1` (49): Bottom-Right Corner (┘) [High]
- `G-N` (71-78): Map borders/edges (┐, ┘, └, ┌, ─, ─, │, │) [High]
- `X-Z` (88-90): Caps and Crosses (┤, ├, ╳) [Medium]
- `[` (91): Horizontal/Vertical Cross (┼) [High]
- `\` (92): Up Arrow (↑) [High]
- `]` (93): Down Arrow (↓) [High]
- `{` (123): Inverse Up Arrow (⬆) [Medium]
- `|` (124): Inverse Down Arrow (⬇) [Medium]
- `}` (125): Inverse Up-Down Arrow (⇕) [Medium]
- `~` (126): Inverse Question Mark (¿) [Low]
