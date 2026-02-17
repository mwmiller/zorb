# Zorb Usage Rules (for Library Consumers)

If you are building an application that uses Zorb to run Z-machine stories, follow these rules and conventions.

## Core Mandates for Consumers

- **Z-Machine Versions**: Zorb supports Versions 1-5 and 7-8. **Version 6 is not supported.** Ensure your story files match these versions.
- **Async Communication**: Zorb is asynchronous. Interaction happens via message passing. Your process **must** be prepared to handle a stream of output messages.
- **Compilation Artifacts**: Zorb generates temporary files (WASM capsules and sidecar payloads). By default, these are in a system temp directory. If your environment (like Heroku or some Docker setups) has a read-only filesystem, you **must** configure `working_dir` to a writable path.

## Elixir Integration

### Starting a Session
Use `Zorb.run/2` to start a new game session. This returns `{:ok, pid}` for a GenServer.

```elixir
# In a Phoenix Channel or LiveView
{:ok, session_pid} = Zorb.run("path/to/zork1.z3", notify_to: self(), cache: true)
```

### Handling Game Output
Your process will receive `{:zorb_output, data}` messages.

- **Characters**: `{:zorb_output, char}` where `char` is an integer (ZSCII/Unicode).
- **Screen Commands**: `{:zorb_output, {command, ...}}` for advanced rendering:
    - `{:cursor, line, col}`: Move the cursor.
    - `{:set_window, window_id}`: Select active window (0=Lower, 1=Upper).
    - `{:split_window, lines}`: Split screen (Window 1 gets top N lines).
    - `{:style, style_id}`: Change style (0=Normal, 1=Reverse, 2=Bold, 4=Italic, 8=Fixed).
    - `{:colour, fg, bg}`: Change colors (1=Def, 2=Blk, 3=Red, 4=Grn, 5=Yel, 6=Blu, 7=Mag, 8=Cyn, 9=Wht).
    - `{:sound, number}`: Play a sound effect (1=High beep, 2=Low beep).
    - `{:erase_window, window_id}`: Clear a window.
    - `{:erase_line, value}`: Erase current line.

### Handling Game Termination
When the game ends (or crashes), you will receive:
- `{:zorb_halt, reason, pc, opcode}`
    - `reason 0`: Normal quit.
    - `reason > 0`: VM error (e.g., stack overflow).

### Sending Input
Send input to the session PID using `Zorb.Session.send_input/2`.

```elixir
Zorb.Session.send_input(session_pid, "open mailbox\n")
```

### External State Management (New)
You can trigger save and restore operations from Elixir, independent of game-loop commands. These return `1` on success and `0` on failure.

```elixir
# Create a snapshot of the current state
Zorb.Session.save(session_pid)

# Restore to the last snapshot
Zorb.Session.restore(session_pid)

# Manage the undo stack
Zorb.Session.save_undo(session_pid)
Zorb.Session.restore_undo(session_pid)
```

### Cache Management
To clear all compiled capsules and temporary artifacts:

```elixir
Zorb.clear_cache()
```

### Save and Restore (In-Game)
`Zorb.Session` automatically handles the Z-machine `save` and `restore` instructions by storing the game state in the session's memory. This allows players to use the in-game "save" and "restore" commands seamlessly.

### Undo (V5+ In-Game)
`Zorb.Session` maintains a stack of up to 16 previous game states for use with the `undo` command in V5+ stories.

## Configuration

You can configure Zorb in your `config/config.exs`:

```elixir
config :zorb,
  working_dir: "/tmp/zorb_artifacts",
  cache_dir: "/tmp/zorb_cache"
```

## Host Interface (Advanced)

If you are implementing your own low-level host instead of using `Zorb.Session`, the Game Capsule exports a set of `zio_` prefixed functions.

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
