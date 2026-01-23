# Handoff - Zorb

Zorb is a high-performance, idiomatic WebAssembly Z-machine interpreter built using Elixir and the Orb DSL. It aims to provide a fast and secure environment for running interactive fiction on the web or any WASM-compatible runtime.

## Current State

- **Runtime**: Uses `wasmex` (~> 0.14.0) for executing WebAssembly modules.
- **Architecture**: Uses a prime number of memory pages (13) and semantic custom WASM types (`T.Address`, `T.Object`, etc.).
- **Robustness**: Implemented write-guards for static memory, stack overflow checks, and a `zio.halt` fatal error interface.
- **Performance**: Version-specific offsets and packed address shifts are cached in global variables during initialization. Dictionary lookups use an efficient binary search. Fast `load_story` bulk copy implemented.
- **I/O & Opcodes**:
  - Implemented `read`, `print_num`, `read_char`, `print_char`, `print_obj`, `print_zstring`, `print_unicode`, `check_unicode`, `set_font`.
  - Implemented `test_attr`, `set_attr`, `clear_attr`, `test`, `get_prop_addr`.
  - Robust opcode dispatch distinguishing VAR vs 2OP-VAR forms and handling extended opcodes.
  - ZSCII handling for input and output, including Unicode support and Font 3 mapping.
  - **Standalone**: Font state and character mapping are handled *entirely* within the WASM module (`Zorb.Interpreter`), reducing host dependency.
- **Spec**: `ZMACHINE_SPEC.md` updated with I/O, opcode tables, and Unicode/Font 3 details.

## Recent Accomplishments

- **Opcode Fixes**: Standardized opcode indices for `test_attr`, `set_attr`, `clear_attr`, `test`, and `and` to match the Z-machine specification.
- **Zorb.Runner**: Implemented a host runner in Elixir using `wasmex` to load and execute `.z3` files with terminal-based I/O.
- **Font 3 (Graphics)**: Implemented `set_font` (EXT:4) and character mapping for Runes/Graphics in `Zorb.Interpreter`.
  - Expanded mapping to include box-drawing characters based on "best-guess" bitmap analysis.
  - Annotated source code with confidence levels (High/Medium/Low).
  - Used Elixir unquoting and Macro escaping to generate efficient WASM branch logic.
- **Unicode**: Implemented `print_unicode` (EXT:11) and `check_unicode` (EXT:12) internally in WASM.
- **Wasmex Migration**: Replaced `orb_wasmtime` with `wasmex`.

## Known Issues

- **zio.halt Interface**: All tests now include a mock for `halt` that returns `0`.
- **Input Timing**: `read_char` and `read` do not yet support timed input (V4+ feature).

## Next Steps

0.  **P0: Static Specialization & Version-Specific Emission**:
    - Refactor `Zorb.Interpreter` from a monolithic module into a generator that accepts a Z-Machine version (and optionally story data).
    - Use Elixir `unquote` to bake version-specific constants (like `@object_entry_size`, `@packed_address_shift`) directly into the WASM as literals, eliminating runtime version checks.
    - Embed the story file directly into the WASM `data` section for per-story specialized builds.
    - Transition from WASM globals for architecture offsets to static compile-time constants.

1.  **Advanced Opcodes**: Implement `random`, `scan_table`, and `verify`.
2.  **Serialization**: Implement `save` and `restore` opcodes for state persistence.
3.  **Loader Utility**: Create a utility to load and initialize the interpreter with `.z3` and `.z5` story files.
4.  **Screen Model**: Implement `split_window`, `set_window`, etc. for V3 status line and V4+ screen features.

## Technical Notes

- **Orb DSL**: Be careful with `I32.match` in complex blocks; prefer `if` statements with `return()` for stability.
- **Memory Layout**: Ensure the stack is properly initialized at the provided offset during `init/1`.
- **Z-machine Versions**: Currently optimized for V3-V5; V8 support is partially implemented via `@packed_address_shift`.
- **Wasmex**: Callbacks receive arguments as a single value (if 1 arg) or list. `TestRuntime` wrapper normalizes this to a list for `apply/2`. Memory operations require passing the `store`.
- **Font 3**: Mapped to Unicode approximates internally in `Zorb.Interpreter`. 

## Latest Thoughts & Architectural Direction

### Static Specialization (P0)
We are moving from a generic interpreter to a **specialized compiler model**.
- **Per-Version**: Generate WASM with version-specific constants baked in (e.g., V3 vs V4 offsets) to eliminate runtime branching in hot paths.
- **Per-Story**: Eventually embed the entire `.z3`/`.z5` file into the WASM `data` section and hardcode dictionary/object table addresses as `I32` literals.
- **Compilation Caching**: Store generated WASM binaries in a content-addressable cache (keyed by `SHA-256(story_bytes) + length`). This avoids redundant Bespoke Generation cycles for popular or frequently accessed stories.

### Serialization & Save/Restore
- **Mechanism**: Use a "Host Import/Pull" model. WASM signals a save, writes its registers to a memory buffer, and the Elixir host reads the dynamic memory region.
- **WASM as Artifact**: The specialized WASM binary itself could technically be "checkpointed" by generating a new binary with save-state data pre-loaded in `data` sections, though standard memory-blob saves are more practical for user files.
- **Isolation**: Specialized binaries naturally protect save files from being loaded into the wrong game/version due to address/logic mismatches.

### Hyper-Hooks & Meta-Interactions (Zorbit)

- **Zorbit**: The nascent name for the Phoenix/LiveView web integration ("Zorb + Orb + Orbit").

- **Input Interception**: Implement a `/` command prefix in `Zorb.Runner` to allow chat/meta-commands to bypass the Z-Machine and trigger Phoenix/LiveView events.



- **Output Injection**: Support asynchronous text injection into the I/O stream (e.g., global chat messages appearing between game turns).

- **Hyper-Opcodes**: Reserve `EXT:255` (0xFF) as a custom Zorb hypercall for explicit host interaction.

- **State Watching**: Implement "Observer" logic in the host to trigger Phoenix events based on changes in Z-Machine globals (e.g., Score updates or Location changes).

### Meta-Layer Slash Commands
For the initial Zorbit release, the host should intercept the following "slash commands" before they reach the Z-Machine:
- `/chat <message>`: Send a standard message to all players "zorbing" the current story.
- `/who`: List active players currently connected to the game instance.
- `/nick <name>`: Set a custom display name for the narrative decoration engine (default to a random "Story-Appropriate" name if not set).
- `/me <action>`: Perform a classic IRC-style emote (e.g., "/me ponders the mailbox" becomes "Matt ponders the mailbox").
- `/help`: Display Zorbit-specific meta-commands (distinct from the in-game "help" command).

### Content Moderation & Safety (The Kessler Prevention)
To maintain a safe multiplayer environment and avoid **Social Kessler Syndrome**, the Zorbit host must implement:
- **The Kessler Risk**: Without rigorous moderation, the "Orbit" becomes clogged with "debris" (toxicity/spam). One bad interaction (collision) generates more negativity (fragments), leading to a cascade that makes the game's social atmosphere uninhabitable for everyone.
- **Pre-flight Moderation**: All `/chat`, `/nick`, and `/me` content must be "de-fanged" (HTML escaping, script removal) and checked against a moderation filter before being broadcast.
- **Low-Cost Filtration Strategies**:
    - **Compiled Regex Triage**: Use a single compiled regex for O(N) pattern matching against banned word lists.
    - **Entropy/Density Checks**: Detect and block "garbage" strings by measuring non-alphanumeric ratios and vowel density.
    - **Similarity Matching**: Use Jaro-Winkler or Levenshtein distance to catch "leetspeak" or intentional misspellings of banned terms.
    - **Velocity Control**: Implement token-bucket rate limiting to prevent flooding.
    - **Echo Suppression**: Block repetitive or near-identical messages from the same source.
- **Auto-Denial**: If a message is flagged as inappropriate, it is blocked at the source.
 The offending user should receive a private system notification explaining the rejection.
- **Privilege Management**: Automated or moderator-led revocation of chat privileges for repeat offenders.
- **Shadow-Banning (Optional)**: A "Tumble-only" mode where an offender's messages appear to send but are never broadcast to other users in the orbit.

### Narrative Decoration Engine
- **Immersive Context**: Instead of generic chat overlays, the Elixir host "skins" meta-events to match the specific story's world (e.g., "The ship's computer mutters..." for HHGTTG).
- **Static Manifests**: To avoid runtime overhead, the "voice" of the story is extracted during the **Bespoke Generation** phase and embedded directly into the WASM binary (either in a high-memory `data` segment or a WASM Custom Section).
- **Game Capsule**: This makes the `.wasm` file a self-contained "Game Capsule" containing the interpreter engine, the story bytes, and the social/narrative metadata in a single, atomic artifact.
- **Hook Integration**: The Phoenix Hook or LiveView process uses this manifest to wrap incoming PubSub messages instantly, ensuring the multiplayer layer "feels" native to the 1980s story bytes.
