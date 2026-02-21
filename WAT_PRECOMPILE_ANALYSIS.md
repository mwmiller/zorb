# WAT Precompilation Analysis

**Date**: February 21, 2026  
**Status**: Not Feasible with Current Architecture

## Investigation Results

### Compilation Breakdown (V5 Czech Story)
- Assembler: 463ms (12.4%)
- **Code.compile_string: 3,079ms (82.2%)** ← Bottleneck
- Orb.to_wat: 121ms (3.2%)
- Watusi.to_wasm: 81ms (2.2%)

**Total**: 3,743ms

### Why WAT Precompilation Won't Work

The story data is loaded at **Elixir compile time** via:

```elixir
@payload File.read!(unquote(payload_path)) |> :erlang.binary_to_term()
```

This means:
1. Each story needs a unique payload file
2. The payload path is baked into the generated Elixir source
3. `Code.compile_string` must run for each story to load its specific payload
4. The compiled module contains story-specific data in its memory initialization

### What We Can't Do

❌ Precompile one WAT template and inject story data  
❌ Reuse compiled modules across stories  
❌ Skip `Code.compile_string` entirely  
❌ Generate WAT directly from AST (Orb requires compiled modules)  

### What We Already Have

✅ **WASM caching** - 654μs for cache hits (9,355x speedup)  
✅ **Version branch pruning** - 100% elimination, 1.4KB savings  
✅ **Optimized assembler** - Only 12.4% of compile time  

### The Real Solution

The **cache IS the optimization**. Cold compilation (3.7s) only happens once per story. Subsequent loads are 654μs.

For users compiling many stories:
- First compile: 3.7s per story
- All subsequent: 654μs per story
- Cache persists across runs

### Alternative Approaches (Future)

To eliminate the Elixir compilation bottleneck entirely would require:

1. **Runtime story loading** - Load story data at WASM runtime, not compile time
   - Major architecture change
   - Story data would need to be passed as imports
   - Memory initialization would happen at instantiation

2. **Ahead-of-time WAT generation** - Generate WAT without Elixir/Orb
   - Write a custom WAT generator
   - Bypass Elixir entirely
   - Significant development effort

3. **Composable architecture** - Pre-compile interpreter, load stories dynamically
   - See COMPOSABLE_ARCHITECTURE.md
   - Different trade-offs (larger base, smaller per-story)

## Conclusion

**WAT precompilation is not feasible** with the current "baking factory" architecture where story data is embedded at Elixir compile time.

The **cache provides the performance** we need:
- Cold: 3.7s (acceptable for one-time compilation)
- Hot: 654μs (excellent for repeated use)

Further optimization requires architectural changes that trade off the benefits of bespoke capsules.

**Recommendation**: Accept current performance. The cache works well.
