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

## Configuration

You can configure Zorb in your `config/config.exs`:

```elixir
config :zorb,
  working_dir: "/tmp/zorb_artifacts",
  cache_dir: "/tmp/zorb_cache"
```

## Host Interface (Advanced)

If you are implementing your own low-level host instead of using `Zorb.Session`, you must provide the `zio` WASM namespace. See [CAPSULE_HOST.md](./CAPSULE_HOST.md) for the required function signatures and implementation details.
