# Zorb Project Handoff - February 4, 2026

## Current Status: STABLE BASE ACHIEVED
The project has successfully reached a stable baseline where the core Z-machine logic is fully compatible with the current `Orb` (0.2.2) DSL. All **8 prover integration tests** are passing.

## The Struggle: The "Baking Factory" vs. Elixir Module Lifecycle
The initial attempt to implement the **Game Capsule** architecture relied on dynamic source code generation (`String.replace`) followed by `Code.eval_string`. This approach proved extremely fragile due to:
1.  **Attribute Persistence**: `Orb` relies heavily on module attributes (`@wasm_imports`, etc.) which do not always persist or expand correctly when modules are defined inside an `eval_string` or a macro.
2.  **Operator Overloading & Guards**: The proven interpreter used `case` statements with guards (e.g., `v when v < 16`). Because `Orb` overloads operators for WASM variable references, these guards failed at compile-time because they couldn't be evaluated by the standard Elixir guard system.
3.  **Case Matching**: Pattern matching directly on WASM local variables (which are structs like `%Orb.VariableReference{}`) in `case` statements is not supported in the current version of `Orb`.

## The New Vision: Programmatic AST Transformation
To overcome these issues, we have pivoted to a more robust "AST-first" approach:
1.  **Proven Logic Base**: The interpreter logic has been refactored to use `if/else` chains instead of `case` blocks for WASM variables. This is now the "proven base" in `lib/zorb/interpreter.ex`.
2.  **Extracted Logic Body**: The core globals and functions have been extracted into `lib/zorb/interpreter/logic_body.exs`.
3.  **Future Game Capsules**: Instead of `eval_string`, the `Zorb.Capsule` system will transition to programmatically constructing `Orb.ModuleDefinition` structs. It will take the proven AST from `logic_body.exs` and inject story-specific data segments and globals at the AST level before final WASM generation.

## Key Changes in this Session
- **Refactored `Zorb.Interpreter`**: Replaced all problematic `case` statements with `if/else` blocks.
- **Fixed Type Duplication**: Moved types to a dedicated `Zorb.Interpreter.Types` module to avoid redefinition errors.
- **Import Stabilization**: Corrected the `zio` namespace import registration.
- **Testing**: Updated `Zorb.Runner` and `Zorb.ProverTest` to ensure output messages are correctly routed to the test process.

## Immediate Next Steps
- Finalize the `Zorb.Capsule` transition to use programmatic AST assembly instead of the current `Logic.generate_module_source` string-based approach.
- Ensure the `v_at_least` macro correctly handles `nop()` for empty branches to satisfy `Orb`'s requirement that every block returns a valid WASM instruction.