# Zorb Performance Baseline

**Date**: February 21, 2026  
**Version**: 0.8.0  
**System**: macOS  

## Executive Summary

- **Cold Compilation**: ~4.24s average (no cache)
- **Cache Write**: ~4.78s average (compile + write to cache)
- **Cache Hit**: ~454μs average (**9,321x speedup**)
- **WASM Size**: 1.18x - 14.96x story file size (depends on story size)

## Detailed Results

### Compilation Performance (Cold - No Cache)

| Story Version | Time | WASM Size |
|--------------|------|-----------|
| V1 - Zork I | 4.49s | 130.01KB |
| V2 - Zork I | 4.15s | 125.73KB |
| V3 - ZIL Test | 3.95s | 71.72KB |
| V5 - Simple Test | 3.83s | 52.35KB |
| V5 - Czech Prover | 3.96s | 61.88KB |
| V5 - StrictZ | 4.04s | 52.85KB |
| V5 - Unicode Test | 4.06s | 53.36KB |
| V7 - Simple Test | 4.12s | 52.35KB |
| V8 - Lost Pig | 5.53s | 327.89KB |

### Compilation Performance (Hot - Cache Hit)

| Story Version | Time | Speedup |
|--------------|------|---------|
| V1 - Zork I | 629μs | 7,139x |
| V2 - Zork I | 555μs | 7,477x |
| V3 - ZIL Test | 316μs | 12,500x |
| V5 - Simple Test | 289μs | 13,252x |
| V5 - Czech Prover | 261μs | 15,172x |
| V5 - StrictZ | 279μs | 14,480x |
| V5 - Unicode Test | 270μs | 15,037x |
| V7 - Simple Test | 241μs | 17,095x |
| V8 - Lost Pig | 1.25ms | 4,424x |

### WASM Size Analysis

| Story Version | Story Size | WASM Size | Ratio |
|--------------|-----------|-----------|-------|
| V1 - Zork I | 81.0KB | 130.01KB | 1.61x |
| V2 - Zork I | 76.72KB | 125.73KB | 1.64x |
| V3 - ZIL Test | 22.83KB | 71.72KB | 3.14x |
| V5 - Simple Test | 3.5KB | 52.35KB | 14.96x |
| V5 - Czech Prover | 13.0KB | 61.88KB | 4.76x |
| V5 - StrictZ | 4.0KB | 52.85KB | 13.21x |
| V5 - Unicode Test | 4.5KB | 53.36KB | 11.86x |
| V7 - Simple Test | 3.5KB | 52.35KB | 14.96x |
| V8 - Lost Pig | 278.5KB | 327.89KB | 1.18x |

## Key Observations

1. **Cache is Highly Effective**: The cache provides a massive speedup (9,321x average), reducing compilation from seconds to microseconds.

2. **Compilation Time Scales with Story Size**: Larger stories (Lost Pig at 278KB) take longer to compile (5.53s) than smaller ones (Simple Test at 3.5KB takes 3.83s).

3. **WASM Overhead**: Small stories have high WASM overhead (14.96x for 3.5KB stories) due to fixed interpreter code. Large stories have minimal overhead (1.18x for 278KB stories).

4. **Consistent Performance**: Compilation times are consistent across Z-machine versions (V1-V8), suggesting the bottleneck is in the WASM generation pipeline, not version-specific logic.

## Performance Bottlenecks to Investigate

Based on these baselines, we've identified the following bottlenecks:

### 1. **Elixir Compilation** (83.3% of time, ~4.8s)

The biggest bottleneck is `Code.compile_string/1` compiling the generated 4,496-line Elixir module.

**Root Cause**: The Assembler generates a large Elixir AST (108KB source) that includes:
- The entire Z-machine interpreter logic (from `interpreter.ex`)
- Story-specific data and configuration
- Memory initialization code

**Potential Optimizations**:
- ✅ **Use the cache** - Already provides 9,321x speedup for repeated compilations
- ⚠️ **Pre-compile interpreter** - Consider compiling the interpreter once and injecting story data at runtime (would require architecture change)
- ⚠️ **Reduce generated code size** - Minimize AST transformations
- ⚠️ **Parallel compilation** - Compile multiple stories in parallel (user-level optimization)

### 2. **Assembler** (12.3% of time, ~712ms)

The Sourceror-based AST assembly takes significant time.

**Potential Optimizations**:
- Reduce AST transformations
- Cache intermediate AST representations
- Profile Sourceror operations to find hotspots

### 3. **WAT/WASM Generation** (4.3% of time, ~250ms combined)

Orb.to_wat (131ms) + Watusi.to_wasm (118ms) are relatively fast but could be optimized.

**Potential Optimizations**:
- These are external dependencies (Orb, Watusi)
- Minimal optimization opportunity without modifying dependencies

### 4. **WASM Size** (especially for small stories)

Small stories have high WASM overhead (~50KB baseline) due to fixed interpreter code.

**Potential Optimizations**:
- Strip unused opcodes for specific story versions
- Compress WASM output
- Use WASM features more efficiently

## Recommended Next Steps

1. **Accept current performance** - With caching, compilation is <1ms. Cold compilation of 4-5s is acceptable for a one-time operation.

2. **Document cache usage** - Ensure users know to use `cache: true` for production.

3. **Consider parallel compilation** - For batch processing, compile multiple stories in parallel.

4. **Profile Assembler** - If further optimization is needed, profile the Sourceror-based assembly.

5. **Investigate pre-compilation** - For advanced optimization, consider pre-compiling the interpreter and injecting story data at runtime (major architecture change).

## Running the Benchmark

```bash
mix run bench/benchmark.exs
```

## Next Steps

1. Profile the compilation pipeline to identify the slowest component
2. Investigate if Orb or Watusi can be optimized
3. Consider parallel compilation for multiple stories
4. Explore reducing WASM baseline size for small stories
