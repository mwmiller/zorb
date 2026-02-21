# Zorb Compilation Performance Profile

## Current Performance (v0.9.0)

### Patcher Method (Default)
- **Compilation time:** ~1ms
- **Speedup:** 6000x over traditional
- **Memory overhead:** 335 KB (all templates)
- **Method:** Patch pre-compiled WASM templates with story data

### Traditional Method (Debugging)
- **Compilation time:** ~4000ms
- **Use case:** Debugging and development only
- **Method:** Full Elixir compilation pipeline

## Traditional Compilation Breakdown

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
Converting the AST back to source code takes 400ms. This is **necessary** because:
- `Code.compile_quoted/1` requires strict AST structure
- Our AST manipulation (replacing nodes, pruning branches) breaks the structure
- Sourceror normalizes the AST by round-tripping through source code
- Attempting to skip this step causes `FunctionClauseError` in Orb macros

### Orb + Watusi (5%)
The actual WASM generation is relatively fast:
- Orb.to_wat: ~100ms (BEAM → WAT)
- Watusi.to_wasm: ~75ms (WAT → WASM binary)

### AST Manipulation (<1%)
Our pruning and transformation work is negligible - only ~35ms total.

## Optimization Strategy: WASM Patcher ✅ **IMPLEMENTED**

Pre-compile interpreter templates to WASM at compile-time, then patch with story data at runtime. Eliminates the 82% Elixir compilation cost.

**Achieved speedup:** 6000x (from ~4s to ~1ms)  
**Implementation:** Zorb.Templates + Zorb.Patcher + Watusi 0.4.0  
**Status:** Complete (v0.9.0)
Attempted to use `Code.compile_quoted/1` directly but our AST manipulation breaks the structure required by Orb macros.

**Estimated speedup:** 1.1x  
**Complexity:** High (requires rewriting AST manipulation to preserve structure)  
**Status:** Not worth the effort for 10% gain

### 3. Persistent BEAM Module
Keep the compiled Orb module in memory, only regenerate WASM with new data.

**Estimated speedup:** 5x  
**Complexity:** High (requires runtime code generation)  
**Status:** Superseded by linker approach

## Recommendation

**Build the WASM linker.** It's the cleanest solution and eliminates the dominant bottleneck (82%).
