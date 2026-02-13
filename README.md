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

You can run a Z-machine story file (V1-V5, V7-V8) directly from the CLI. First, build the standalone executable:

```bash
mix escript.build
```

Then run a story:

```bash
./zorb_interpreter path/to/your/story.z5 --cache
```

### Programmatic Usage

To run a story within your own Elixir application:

#### Using Zorb.run/2 (Recommended)

`Zorb.run/2` starts a `Zorb.Session` (a GenServer) that provides a non-blocking, asynchronous interface. It is ideal for use in Phoenix channels or anywhere you need a long-lived, supervised process.

```elixir
# Start the session from a story file with caching enabled
{:ok, session_pid} = Zorb.run("path/to/story.z5", cache: true)

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

- [usage-rules.md](./usage-rules.md): Essential rules and conventions for library consumers, including the WASM host interface.
- [Z-Machine Specification](https://zspec.jaredreisinger.com/): The official Z-machine specification.

## Development

### Running Tests
All integration tests use the bespoke capsule system:
```bash
mix test
```
The first run for a new story file may take several seconds as it "bakes" the optimized capsule. Compilation is currently handled on the consumer side; if intermediate artifacts emerge that benefit from shared persistence, a global cache may be reintroduced.

### Test Resources
For additional Z-machine test files and stories, we recommend the [zifmia](https://github.com/jeffnyman/zifmia) repository.

