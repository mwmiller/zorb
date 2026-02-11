# Zorb (Z-machine in Orb)

Zorb is a modern Z-machine implementation that compiles Z-machine story files into highly optimized, standalone WASM "Game Capsules".

## Putting Zorb to Work

Zorb transforms classic interactive fiction into modern WebAssembly artifacts.

### Prerequisites
- Elixir 1.15+
- Wasmex (for execution)
- Orb (for WASM generation)

### Installation

Add `zorb` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:zorb, "~> 0.2.0"}
  ]
end
```

### Running a Story

You can run a Z-machine story file (V1-V5, V7-V8) directly from the CLI.

#### Building the Escript

```bash
mix escript.build
./zorb path/to/your/story.z5
```

Alternatively, use the provided wrapper script:

```bash
bin/run_story path/to/your/story.z5
```

### Programmatic Usage

To run a story within your own Elixir application:

#### Using Zorb.Session (Recommended for Phoenix/OTP)

`Zorb.Session` is a `GenServer` that provides a non-blocking, asynchronous interface. It is ideal for use in Phoenix channels or anywhere you need a long-lived, supervised process.

```elixir
# Start the session from a story file with caching enabled
{:ok, session_pid} = Zorb.Session.start_link({:story_path, "path/to/story.z5"}, notify_to: self(), cache: true)

# Or start from previously compiled WASM bytes (WAT also accepted)
{:ok, session_pid} = Zorb.Session.start_link({:wasm_bytes, wasm_binary}, notify_to: self())

# Listen for messages in your process
receive do
  {:zorb_output, char} when is_integer(char) -> 
    IO.write([char])
  {:zorb_output, {:cursor, line, col}} -> 
    # Handle screen model commands
    :ok
  {:zorb_halt, reason, pc, _opcode} ->
    IO.puts("Game halted.")
end

# Send input to the game
Zorb.Session.send_input(session_pid, "look\n")
```

## Core Architecture: Game Capsules

Unlike traditional Z-machine interpreters that load and interpret story data at runtime, Zorb uses a **Baking Factory** approach. Stories are transformed into bespoke WASM binaries where the story data is baked in, and the interpreter logic is optimized for that specific story's version.

- **Bespoke Generation**: Optimized capsules eliminate runtime JIT overhead.
- **WASM Tokenizer**: High-performance tokenization with O(1) dictionary lookups via baked-in hash tables.
- **Host Interface**: Standardized `zio` namespace for I/O and system calls.

## Documentation

- [ZMACHINE.md](./ZMACHINE.md): Comprehensive Z-machine specification and implementation notes.
- [CAPSULE_HOST.md](./CAPSULE_HOST.md): Technical details on the WASM host interface.
- [AGENTS.md](./AGENTS.md): Guidelines for developer agents working on the codebase.
- [HANDOFF.md](./HANDOFF.md): Latest project status and handoff notes.

## Development

### Running Tests
All integration tests use the bespoke capsule system:
```bash
mix test
```
The first run for a new story file may take several seconds as it "bakes" the optimized capsule. Compilation is currently handled on the consumer side; if intermediate artifacts emerge that benefit from shared persistence, a global cache may be reintroduced.

### Test Resources
For additional Z-machine test files and stories, we recommend the [zifmia](https://github.com/jeffnyman/zifmia) repository.

