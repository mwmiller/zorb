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

### Save and Restore
`Zorb.Session` automatically handles the Z-machine `save` and `restore` instructions by storing the game state in the session's memory. This allows players to use the in-game "save" and "restore" commands seamlessly.

### Undo (V5+)
`Zorb.Session` maintains a stack of up to 16 previous game states for use with the `undo` command in V5+ stories.

## Configuration

You can configure Zorb in your `config/config.exs`:

```elixir
config :zorb,
  working_dir: "/tmp/zorb_artifacts",
  cache_dir: "/tmp/zorb_cache"
```

## Host Interface (Advanced)

If you are implementing your own low-level host instead of using `Zorb.Session`, you must provide the `zio` WASM namespace.

### Required Interface

The Host **must** provide the following functions:

- `print_char(char: i32)`: Outputs a single ZSCII/Unicode character.
- `print_num(num: i32)`: Outputs a signed 32-bit integer.
- `read_char() -> i32`: Waits for a single character input and returns its ZSCII value.
- `get_random(max: i32) -> i32`: Returns a random integer between 1 and `max`.
- `get_random_seed() -> i32`: Returns a 32-bit integer to seed the PRNG.
- `halt(reason: i32, pc: i32, opcode: i32)`: Called on fatal error or `quit`.
- `sound_effect(number: i32)`: Plays a sound effect (1=High beep, 2=Low beep).

### Screen Model Interface (V3-V8)

If the Host signals support via `get_capabilities`, it **must** provide:

- `set_window(window_id: i32)`: Directs output to the specified window (0=Lower, 1=Upper).
- `split_window(lines: i32)`: Splits the screen; Window 1 occupies the top `lines`.
- `set_cursor(line: i32, col: i32)`: Moves the cursor (1-indexed).
- `erase_window(window_id: i32)`: Clears the specified window (-1 for entire screen).
- `erase_line(value: i32)`: Erases from cursor to end of line.
- `set_text_style(style: i32)`: Sets bit-mapped text style (Bold, Italic, etc.).
- `set_colour(foreground: i32, background: i32)`: Sets text colors.
- `get_screen_size() -> i32`: Returns packed `[height:16, width:16]`.

### Save/Restore Interface

If you are implementing a custom host, you must provide:

- `save(pc, sp, fp, csp, rs) -> i32`: Save the game state and return 1 (success) or 0 (failure).
- `restore() -> i32`: Restore the game state and return 1 (success) or 0 (failure).
- `get_restored_pc() -> i32`: Return the PC from the last restored state.
- `get_restored_sp() -> i32`: Return the SP from the last restored state.
- `get_restored_fp() -> i32`: Return the FP from the last restored state.
- `get_restored_csp() -> i32`: Return the CSP from the last restored state.
- `get_restored_random_state() -> i32`: Return the random state from the last restored state.

### Undo Interface (V5+)

- `save_undo(pc, sp, fp, csp, rs) -> i32`: Save the game state for undo and return 1 (success), 0 (failure), or -1 (not supported).
- `restore_undo() -> i32`: Restore the game state from the undo stack and return 1 (success) or 0 (failure).
- `get_undone_pc() -> i32`: Return the PC from the last undone state.
- `get_undone_sp() -> i32`: Return the SP from the last undone state.
- `get_undone_fp() -> i32`: Return the FP from the last undone state.
- `get_undone_csp() -> i32`: Return the CSP from the last undone state.
- `get_undone_random_state() -> i32`: Return the random state from the last undone state.

### Optional Interface (Capabilities)

The Host can signal support for optional features via `get_capabilities() -> i32` (bitmask):
- `0x01`: Status line.
- `0x02`: Screen splitting.
- `0x04`: Variable-width font.
- `0x08`: Font 3 (Graphics).
- `0x10`: Color.
- `0x20`: Timed input.
