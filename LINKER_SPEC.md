# WASM Linker Requirements for Zorb

## Overview
Pre-compile the Z-machine interpreter to WASM once per version (V1-V8), then link it with story-specific data to produce game capsules in ~400ms instead of ~4000ms.

## Required WASM Linker Features

### 1. Data Segment Injection ⭐ CRITICAL
Replace or inject data segments at specific memory addresses.

**Memory Layout:**
```
0x00000 - 0x7FFFF : Story data (variable size, up to 512KB)
0x80000 - 0x80FFF : Unicode table (4KB, 194 bytes used, V5+ only)
0x81000 - 0x81FFF : Alphabet table (4KB, 104 bytes used)
0x82000 - 0x89FFF : Dictionary hash table (32KB, size varies)
0x8A000 - 0x8AFFF : Metadata (4KB, 138 bytes used)
0x90000+          : Runtime stack
0x98000+          : Call stack
```

**Required Operations:**
- Replace data segment at offset 0x00000 with story bytes
- Replace data segment at offset 0x80000 with unicode table (or empty for V1-V4)
- Replace data segment at offset 0x81000 with alphabet table
- Replace data segment at offset 0x82000 with dictionary hash table
- Replace data segment at offset 0x8A000 with metadata

**WASM Spec:** [Data Section](https://webassembly.github.io/spec/core/binary/modules.html#data-section) (Section 11)

### 2. Global Variable Initialization ⭐ CRITICAL
Set initial values for global variables.

**Globals to Initialize:**
```wasm
@version              : i32  (1-8, story version)
@globals_base         : i32  (from story header offset 0x0C)
@static_memory_base   : i32  (from story header offset 0x0E)
@dictionary_base      : i32  (from story header offset 0x08)
@object_table_base    : i32  (from story header offset 0x0A)
@object_table_start   : i32  (calculated: otb + (v<=3 ? 62 : 126))
@abbreviations_base   : i32  (from story header offset 0x18)
@packed_address_shift : i32  (v<=3 ? 1 : 2)
@routine_offset       : i32  (v6-7: header[0x28]*8, else: 0)
@string_offset        : i32  (v6-7: header[0x2A]*8, else: 0)
@object_entry_size    : i32  (v<=3 ? 9 : 14)
@object_parent_offset : i32  (v<=3 ? 4 : 6)
@object_sibling_offset: i32  (v<=3 ? 5 : 8)
@object_child_offset  : i32  (v<=3 ? 6 : 10)
@object_property_table_offset: i32 (v<=3 ? 7 : 12)
@story_len            : i32  (byte size of story data)
```

**WASM Spec:** [Global Section](https://webassembly.github.io/spec/core/binary/modules.html#global-section) (Section 6)

### 3. Constant Folding (Optional, Nice-to-Have)
Replace `i32.const` instructions with story-specific values.

**Example:**
```wasm
;; Pre-compiled template has:
(i32.const 0)  ;; placeholder for dictionary_base

;; After linking:
(i32.const 0x1234)  ;; actual dictionary_base from story
```

This would allow inlining constants instead of loading from globals, but is **not required** for correctness.

**WASM Spec:** [Constant Instructions](https://webassembly.github.io/spec/core/binary/instructions.html#numeric-instructions)

### 4. Function Patching (Optional, for Dictionary Hash)
The dictionary hash function has a version-specific mask baked in:

```wasm
;; In ldict function:
(i32.and (i32.xor $w1 (i32.xor $w2 $w3)) (i32.const <MASK>))
```

Where `<MASK>` = dictionary_hash_table_size - 1 (typically 2047 for 2048 entries).

**Workaround:** Use a global variable for the mask instead of a constant.

**WASM Spec:** [Code Section](https://webassembly.github.io/spec/core/binary/modules.html#code-section) (Section 10)

## Minimal Viable Linker

To get this working, you **MUST** support:

1. ✅ **Data segment replacement** (Section 11)
2. ✅ **Global initialization** (Section 6)

That's it. Everything else is optimization.

## Pre-compilation Strategy

### Step 1: Generate Template WASM per Version
```elixir
# Compile once per version (V1-V8, excluding V6)
for version <- [1, 2, 3, 4, 5, 7, 8] do
  template_wasm = compile_interpreter_template(version)
  File.write!("templates/interpreter_v#{version}.wasm", template_wasm)
end
```

### Step 2: Link at Runtime
```elixir
def compile(story_path) do
  story_data = File.read!(story_path)
  <<version::8, _::binary>> = story_data
  
  template = File.read!("templates/interpreter_v#{version}.wasm")
  
  # Extract story-specific data
  {globals, data_segments} = prepare_link_data(story_data)
  
  # Link
  wasm = Linker.link(template, globals: globals, data: data_segments)
  
  wasm
end
```

## Data Segment Format

Each data segment needs:
- **Offset:** Memory address (u32)
- **Data:** Byte array

Example:
```elixir
data_segments = [
  {0x00000, story_bytes},
  {0x80000, unicode_table},
  {0x81000, alphabet_table},
  {0x82000, hash_table},
  {0x8A000, metadata}
]
```

## Testing the Linker

Minimal test case:
```elixir
# 1. Compile a story the old way
wasm_old = Zorb.Capsule.compile("test.z5")

# 2. Compile using linker
wasm_new = Zorb.Linker.compile("test.z5")

# 3. Both should produce identical behavior
assert run_story(wasm_old, "look") == run_story(wasm_new, "look")
```

## Questions for Your Linker

1. Can it replace data segments at arbitrary offsets?
2. Can it set global variable initial values?
3. Does it preserve function imports (we import from `zio` namespace)?
4. Does it handle multiple data segments (we have 5)?
5. Can it work with WASM modules that have no start function?

If yes to all 5, you're good to go!
