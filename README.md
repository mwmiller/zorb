# Zorb (Z-machine in Orb)

Zorb is a modern Z-machine implementation that compiles Z-machine story files into highly optimized, standalone WASM "Game Capsules".

## Putting Zorb to Work

Zorb transforms classic interactive fiction into modern WebAssembly artifacts.

### Prerequisites
- Elixir 1.15+
- Orb (for WASM generation)
- [Watusi](https://hex.pm/packages/watusi) (for binary generation)

### Installation

Add `zorb` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:zorb, "~> 0.6.0"}
  ]
end
```

### Compiling a Story

You can compile a Z-machine story file (V1-V5, V7-V8) into a standalone WebAssembly capsule:

```elixir
wasm_bytes = Zorb.compile("path/to/story.z5", cache: true)
File.write!("story.wasm", wasm_bytes)
```

## Core Architecture: Game Capsules

Unlike traditional Z-machine interpreters that load and interpret story data at runtime, Zorb uses a **Baking Factory** approach. Stories are transformed into bespoke WASM binaries where the story data is baked in, and the interpreter logic is optimized for that specific story's version.

- **Bespoke Generation**: Optimized capsules eliminate runtime JIT overhead.
- **WASM Tokenizer**: High-performance tokenization with O(1) dictionary lookups via baked-in hash tables.
- **Host Interface**: Standardized `zio` namespace for I/O and system calls. See [CAPSULE_HOST.md](./CAPSULE_HOST.md) for the full interface.

## Documentation

- [usage-rules.md](./usage-rules.md): Essential rules and conventions for library consumers.
- [CAPSULE_HOST.md](./CAPSULE_HOST.md): Complete specification of the WASM Host Interface.
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

