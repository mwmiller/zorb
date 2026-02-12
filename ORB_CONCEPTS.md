# Orb Concepts in Zorb

Zorb leverages the [Orb](https://useorb.dev) DSL to compile Z-machine stories into WebAssembly. Understanding the following core Orb concepts is essential for maintaining Zorb's "Baking Factory" architecture.

## 1. Composable Modules
Orb uses Elixir's module system to create reusable WebAssembly components. By using `Orb.include/1`, Zorb can compose the final Game Capsule from shared building blocks, such as the interpreter logic and story-specific data segments. This allows for a clean separation between the static interpreter engine and the bespoke story data.

## 2. Elixir Compiler Integration
The Elixir compiler is a first-class citizen in the WebAssembly generation process. Orb introduces a "WebAssembly-compile-time" phase that sits between Elixir's own compilation and its runtime. This enables Zorb to:
- Use existing Elixir libraries (like `Sourceror`) to transform the AST.
- Perform complex data processing (like dictionary hashing) at WASM build-time.
- Generate highly optimized, bespoke WASM code that only includes the logic necessary for a specific story version.

## 3. Custom Types
Orb allows defining custom types via the `Orb.CustomType` behaviour. These types map to underlying WebAssembly primitives (like `:i32`) but provide Elixir-side type safety and clarity. In Zorb, we use these for:
- `T.Address`: Ensuring memory offsets are correctly handled.
- `T.Variable`: Clarifying when an integer represents a Z-machine variable index.
- `T.Object`: Distinguishing object IDs from raw numbers.

These types exist only at compile-time and do not introduce any runtime overhead in the final WebAssembly binary.
