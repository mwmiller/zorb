# Zorb (Z-machine in Orb)

Zorb is a modern Z-machine implementation that compiles Z-machine story files into highly optimized, standalone WASM "Game Capsules".

## Core Architecture: Game Capsules

Unlike traditional Z-machine interpreters that load and interpret story data at runtime, Zorb uses a **Baking Factory** approach. Stories are transformed into bespoke WASM binaries where the story data is baked in, and the interpreter logic is optimized for that specific story's version.

### Key Components

- **`Zorb.Capsule`**: The compiler engine. It generates unique WASM modules for each story, featuring:
    - Persistent caching in `tmp/zorb_cache/`.
    - Versioned artifacts for reproducible builds.
    - Compile-time version branching (eliminates runtime version checks).
- **`Zorb.Interpreter.Logic`**: The shared Z-machine implementation macro.
- **`Zorb.Capsule.Host`**: Defines the contract between the Capsule and the hosting environment (see `CAPSULE_HOST.md`).
- **`Zorb.Runner`**: The Elixir-side runner that manages the WASM lifecycle and I/O.

## Caching & Versioning

Bespoke capsules are cached to avoid redundant compilation. The cache key is derived from:
1. The **Compiler Version** (defined in `Zorb.Capsule`).
2. The **Story File Size**.
3. A **SHA-256 Hash** of the story header.

Artifacts are stored at: `tmp/zorb_cache/<compiler_version>/<cache_key>.wasm`.

## Host Interface

Hosting a Zorb Capsule requires providing a small set of WASM imports in the `zio` namespace. 
See [CAPSULE_HOST.md](./CAPSULE_HOST.md) for the full interface specification.

## Development

### Prerequisites
- Elixir 1.15+
- Wasmex (for execution)
- Orb (for WASM generation)

### Running Tests
All integration tests now use the bespoke capsule system:
```bash
mix test test/zorb_prover_test.exs
```
Note: The first run for a new story file may take several seconds as it "bakes" the optimized capsule. Subsequent runs will be near-instant due to caching.