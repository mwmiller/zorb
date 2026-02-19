# Zorb Usage Rules (for Library Consumers)

If you are building an application that uses Zorb to compile Z-machine stories, follow these rules and conventions.

## Core Mandates for Consumers

- **Z-Machine Versions**: Zorb supports Versions 1-5 and 7-8. **Version 6 is not supported.** Ensure your story files match these versions.
- **WASM Interface**: Zorb generates WASM Game Capsules that follow the `zio` host interface. You must provide a host environment (in Elixir, JavaScript, or another WASM-capable language) to execute these capsules.
- **Compilation Artifacts**: Zorb generates temporary files (WASM capsules and sidecar payloads). By default, these are in a system temp directory. If your environment (like Heroku or some Docker setups) has a read-only filesystem, you **must** configure `working_dir` to a writable path.

## Elixir Integration

### Compiling a Story
Use `Zorb.compile/2` to generate a WebAssembly binary.

```elixir
wasm_bytes = Zorb.compile("path/to/zork1.z3", cache: true)
```

### Analyzing Story Metadata
Use `Zorb.metadata/1` to extract semantic metadata (e.g., for Orbit Radio) from a story file.

```elixir
meta = Zorb.metadata("path/to/story.z5")
# => %{command_prefix: 47, chat_prefix: "ORB", channel_prefix: "SOULS", ...}
```

### Cache Management
To clear all compiled capsules and temporary artifacts:

```elixir
Zorb.clear_cache()
```

## Configuration

You can configure Zorb in your `config/config.exs`:

```elixir
config :zorb,
  working_dir: "/tmp/zorb_artifacts",
  cache_dir: "/tmp/zorb_cache"
```

## Host Interface (Advanced)

Zorb produces Game Capsules that export a set of `zio_` prefixed functions. These can be used to drive the interpreter from a custom Host environment.

### Exported WASM Interface

All capsules export the following functions:

- `zio_save() -> i32`: Triggers a save.
- `zio_restore() -> i32`: Triggers a restore.
- `zio_save_undo() -> i32`: Triggers an undo save.
- `zio_restore_undo() -> i32`: Triggers an undo restore.
- `zio_print_char(char: i32)`: Outputs a character.
- `zio_print_num(num: i32)`: Outputs a number.
- `zio_read_char() -> i32`: Reads a character.
- `zio_set_window(id: i32)`: Selects a window.
- `zio_split_window(lines: i32)`: Splits the screen.
- `zio_set_cursor(line: i32, col: i32)`: Moves the cursor.
- `zio_erase_window(id: i32)`: Clears a window.
- `zio_erase_line(val: i32)`: Erases a line.
- `zio_set_text_style(style: i32)`: Sets text style.
- `zio_set_colour(fg: i32, bg: i32)`: Sets colors.
- `zio_sound_effect(id: i32)`: Plays sound.
- `zio_get_screen_size() -> i32`: Returns packed size.
- `zio_get_capabilities() -> i32`: Returns feature bitmask.
- `zio_halt(reason: i32)`: Terminates the VM.

### Required Imports (The Host Interface)

The Host **must** provide the `zio` namespace with the following functions:

- `print_char(char: i32)`: Outputs a single ZSCII/Unicode character.
- `print_num(num: i32)`: Outputs a signed 32-bit integer.
- `read_char() -> i32`: Waits for a single character input and returns its ZSCII value.
- `get_random(max: i32) -> i32`: Returns a random integer between 1 and `max`.
- `get_random_seed() -> i32`: Returns a 32-bit integer to seed the PRNG.
- `halt(reason: i32, pc: i32, opcode: i32)`: Called on fatal error or `quit`.
- `sound_effect(number: i32)`: Plays a sound effect (1=High beep, 2=Low beep).
- `check_interrupt() -> i32`: (New) Polled by WASM to check for Host-triggered save/restore.
    - `0`: No request.
    - `1`: Save.
    - `2`: Restore.
    - `3`: Save Undo.
    - `4`: Restore Undo.

### Triggering External Operations (Custom Host)
If you are implementing a custom host and wish to trigger a save/restore from outside the Z-machine loop:
1. When an external trigger occurs, return the corresponding code (1-4) from the next `check_interrupt()` call.
2. The Game Capsule will then invoke the appropriate ZIO function (`save`, `restore`, etc.).
3. If the Z-machine is currently waiting for input in `read_char()`, you can return a special character code (`0x101`-`0x104`) from `read_char()` to wake it up and trigger the interrupt immediately.

### Optional Interface (Capabilities)

The Host can signal support for optional features via `get_capabilities() -> i32` (bitmask):
- `0x01`: Status line.
- `0x02`: Screen splitting.
- `0x04`: Variable-width font.
- `0x08`: Font 3 (Graphics).
- `0x10`: Color.
- `0x20`: Timed input.
