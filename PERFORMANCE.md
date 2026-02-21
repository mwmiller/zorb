# Zorb Compilation Performance Profile

## Benchmark Results (Average of 3 story files)

| Phase | Time (ms) | % of Total |
|-------|-----------|------------|
| **Elixir Code.compile_string** | **3,396** | **82%** |
| Sourceror.to_string | 404 | 10% |
| Orb.to_wat | 106 | 3% |
| Watusi.to_wasm | 76 | 2% |
| Data preparation | 9 | <1% |
| AST pruning | 13 | <1% |
| AST generation | 5 | <1% |
| AST transformation | 4 | <1% |
| **Total** | **~4,022** | **100%** |

## Key Findings

### Bottleneck: Elixir Compilation (82%)
The overwhelming bottleneck is `Code.compile_string/1` compiling the generated Orb module. This is where Elixir:
1. Parses the generated source code
2. Expands macros (Orb DSL)
3. Compiles to BEAM bytecode
4. Loads the module

### Secondary Cost: Sourceror (10%)
Converting the AST back to source code takes 400ms. This is necessary because we need to compile the Elixir code.

### Orb + Watusi (5%)
The actual WASM generation is relatively fast:
- Orb.to_wat: ~100ms (BEAM → WAT)
- Watusi.to_wasm: ~75ms (WAT → WASM binary)

### AST Manipulation (<1%)
Our pruning and transformation work is negligible - only ~35ms total.

## Optimization Strategies

### 1. WASM Linker (Your Approach) ✅
Pre-compile interpreter to WASM, link with story data. Eliminates the 82% Elixir compilation cost.

**Estimated speedup:** 5-10x (from ~4s to ~400-800ms)

### 2. Skip Sourceror.to_string
If we could pass AST directly to Orb without round-tripping through source code, we'd save 10%.

**Estimated speedup:** 1.1x

### 3. Persistent BEAM Module
Keep the compiled Orb module in memory, only regenerate WASM with new data.

**Complexity:** High (requires runtime code generation)
**Estimated speedup:** 5x

## Recommendation

**Build the WASM linker.** It's the cleanest solution and eliminates the dominant bottleneck.
