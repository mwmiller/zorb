# Agent Guidelines - Zorb Project

## Priorities
1. **Priority 0: Pass `CZECH` integration test.**
   - The prover `czech.z5` is the source of truth for V5 compliance.
   - Current state: "Indirect Opcodes" partially passing.
   - Investigation area: `pull` (VAR:9) destination indirection vs stack top consumption.

2. **Priority 1: Pass all other integration tests.**
   - Once `CZECH` is green, re-enable and pass `strictz.z5` and `unicode.z5`.

## Absolute Mandates
- **No New Features**: Do not implement meta-commands, sound, or advanced UI until Priority 0 and 1 are achieved.
- **WASM Scoping**: Remember that Elixir assignments inside Orb `if` blocks do NOT set WASM locals. Use `if/else` returns or helper functions.
- **PC Alignment**: Every instruction MUST consume exactly the number of operand bytes specified by its type prefix. Use `fetch_var_operand` to safely consume optional operands.
- **Variable References**: Opcodes taking a variable index (store, load, inc, dec, pull, etc.) must handle variable 0 as SP correctly (pop for index, then pop/push for value).

## Testing
- Run integration tests with: `mix test test/zorb_prover_test.exs`
- Integration tests use a non-blocking `Runner` with an asynchronous input buffer.
- Use `Expect.expect(pattern, timeout, task_pid)` to verify output.
- Use `Expect.dispute(pattern)` to fail early on known error strings (e.g., "ERROR").

## Knowledge Base

### Metaprogramming Elixir (Chris McCord)
Key takeaways for refactoring Zorb:
- **AST Manipulation**: Elixir represents code as tuples `({func, meta, args})`. We can walk and transform this AST to generate boilerplate (like opcode dispatch).
- **Macro Hygiene**: Use `var!` to access variables from the caller's context, but be careful with scope. Unhygienic variables can be useful for DSLs but should be used sparingly.
- **Compile-time Hooks**: Use `@before_compile` to aggregate data (like a list of opcodes) and generate final dispatch functions just before the module is finished compiling.
- **DSL Design**: Start with a Minimum Viable API. For opcodes, a declarative `defopcode` macro can hide the complexity of bitmasking and PC management.
- **Avoid Over-Metaprogramming**: Only use macros when they significantly reduce boilerplate or improve expressiveness. For Zorb, opcode dispatch is a prime candidate.