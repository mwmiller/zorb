# Zorbit: The Bespoke Multiplayer Z-Machine

Zorbit is a high-performance, multiplayer-enabled Z-machine ecosystem built on the foundation of **Zorb** (the WebAssembly interpreter engine) and **Orb** (the Elixir-to-WASM DSL). It transforms classic interactive fiction into modern, social, and atomic WebAssembly artifacts.

## Core Vision

The goal of Zorbit is to move beyond generic interpretation towards a **Specialized Compiler Model**. Instead of a single interpreter loading many games, Zorbit generates a specialized WASM binary for every story, baking game logic, assets, and social metadata into a single "Game Capsule."

## Technical Architecture

### 1. The Game Capsule Model
Zorbit produces self-contained `.wasm` files that act as atomic units of distribution.
- **Story Embedding**: The original `.z3`/`.z5`/`.z8` story bytes are embedded directly into the WASM `data` section.
- **Static Specialization**: Version-specific constants (e.g., object table entry sizes, packed address shifts) are baked in as literals during compilation using Elixir `unquote`.
- **Narrative Manifests**: Social metadata and "Narrative Decoration" manifests (skins for the multiplayer layer) are stored within the binary's high-memory regions or Custom Sections.
- **Explicit Exclusions**: **Version 6 is not supported.** V6 requires a coordinate-based canvas model and graphical asset management that would bloated the Game Capsule and compromise portability. Modern Z-machine usage is dominated by V5/V8, which Zorbit fully targets.

### 2. Compilation & Caching
To ensure responsiveness, Zorbit employs a multi-tiered caching strategy:
- **Content-Addressable Cache**: Generated WASM binaries are keyed by `SHA-256(story_bytes) + engine_version`.
- **Bespoke Generation**: Popular stories are pre-compiled into optimized capsules, eliminating runtime JIT overhead for common games.

### 3. Hyper-Hooks & Host Interaction
Zorbit extends the Z-machine via a "Hyper-Hook" layer:
- **Input Interception**: Slash commands (`/chat`, `/who`, `/me`) are intercepted by the host before reaching the Z-machine.
- **Output Injection**: The Elixir host can inject asynchronous text (e.g., global chat) into the story's I/O stream.
- **Hyper-Opcodes**: Custom opcode `EXT:255` (0xFF) is reserved for explicit game-to-host hypercalls.
- **State Observers**: The host monitors specific Z-machine globals (e.g., Score, Location) to trigger Phoenix/LiveView events.

## Multiplayer & Social Features ("The Orbit")

Zorbit introduces a "social layer" around the narrative, designed for safety and immersion.

### 1. The Kessler Prevention (Safety First)
To avoid "Social Kessler Syndrome"—where unmoderated debris (spam/toxicity) leads to a cascade that makes the environment uninhabitable—Zorbit implements:
- **Pre-flight Moderation**: All meta-content (`/chat`, `/nick`, `/me`) is de-fanged and filtered before broadcast.
- **O(N) Filtration**: Uses compiled regex triage and entropy checks for low-cost, high-speed moderation.
- **Velocity Control**: Token-bucket rate limiting prevents flooding.
- **Shadow-Banning**: A "Tumble-only" mode where offenders see their own messages, but they are never broadcast.

### 2. Narrative Decoration Engine
Multiplayer events are "skinned" to match the game world's context.
- **Immersive Immersion**: Instead of a generic chat box, the host wraps messages in the "voice" of the story (e.g., "The ship's computer mutters..." for *HHGTTG*).
- **Static Voices**: These narrative skins are extracted during the Bespoke Generation phase and embedded in the capsule.

## Roadmap & Priorities

### Phase 1: Engine Compliance (Current)
- [IN PROGRESS] Pass the **CZECH** prover suite for V5.
- [TODO] Implement standard `save`/`restore` via Host Import/Pull model.
- [TODO] Complete the V4+ Screen Model (split windows, status lines).

### Phase 2: Bespoke Generation
- [TODO] Refactor `Zorb.Interpreter` into a version-specific code generator.
- [TODO] Implement the compilation cache and Game Capsule assembler.

### Phase 3: Zorbit Social Layer
- [TODO] Implement the slash command interceptor in `Zorb.Runner`.
- [TODO] Integrate Phoenix/LiveView PubSub for multiplayer "orbits."
- [TODO] Implement the Narrative Decoration Engine.
