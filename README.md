# Zorb (Z-machine in Orb)

Zorb is a modern Z-machine implementation that compiles Z-machine story files into highly optimized, standalone WASM "Game Capsules" with **blazing-fast compilation** (~1ms per story).

## Putting Zorb to Work

Zorb transforms classic interactive fiction into modern WebAssembly artifacts.

### Prerequisites
- Elixir 1.15+
- Orb (for WASM generation)
- [Watusi](https://hex.pm/packages/watusi) (for WASM patching)

### Installation

Add `zorb` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:zorb, "~> 0.9.0"}
  ]
end
```

### Compiling a Story

Compile a Z-machine story file (V1-V5, V7-V8) into a standalone WebAssembly capsule in ~1ms:

```elixir
wasm_bytes = Zorb.compile("path/to/story.z5", cache: true)
File.write!("story.wasm", wasm_bytes)
```

## Performance

Zorb uses a **WASM patcher** for extremely fast compilation:

- **Compilation time:** ~1ms per story (6000x faster than traditional compilation)
- **Memory overhead:** 335 KB for pre-compiled templates (all versions)
- **Cache support:** Instant compilation on cache hits

The patcher works by patching pre-compiled WASM templates with story-specific data, eliminating the need for full Elixir compilation on every story.

## Core Architecture: Game Capsules

Unlike traditional Z-machine interpreters that load and interpret story data at runtime, Zorb uses a **Baking Factory** approach. Stories are transformed into bespoke WASM binaries where the story data is baked in, and the interpreter logic is optimized for that specific story's version.

- **Bespoke Generation**: Optimized capsules eliminate runtime JIT overhead.
- **WASM Patcher**: Pre-compiled templates patched with story data for instant compilation.
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

### Test Resources
For additional Z-machine test files and stories, we recommend the [zifmia](https://github.com/jeffnyman/zifmia) repository.

