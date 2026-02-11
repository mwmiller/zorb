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

You can run a Z-machine story file (V1-V5, V7-V8) directly from the CLI:

```bash
bin/run_story path/to/your/story.z5
```

### Programmatic Usage

To run a story within your own Elixir application:

```elixir
# Start the runner with a story file
{:ok, runner_pid} = Zorb.Runner.run("path/to/story.z5")

# Listen for output
# Output is sent as {:zorb_output, char_code} messages to the calling process
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

