# Composable Interpreter Architecture Proposal

## Problem

Current architecture compiles the entire interpreter (2,763 lines) for each story:
- **83.3% of compilation time** (4.81s) is spent in `Code.compile_string/1`
- The interpreter logic is identical across stories
- Only story-specific data changes (memory, globals, hash tables)

## Proposed Solution: Pre-compiled Interpreter Core

### Architecture

```
┌─────────────────────────────────────────┐
│  Zorb.Interpreter.Core (pre-compiled)   │
│  - All opcode implementations           │
│  - Stack/memory operations              │
│  - Object tree operations               │
│  - String decoding                      │
│  - Compiled once at build time          │
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│  Story-Specific Wrapper (fast compile)  │
│  - Memory initialization                │
│  - Global constants                     │
│  - Dictionary hash table                │
│  - Imports Core functions               │
└─────────────────────────────────────────┘
```

### Implementation Strategy

#### Option 1: WAT Template (Fastest)

Pre-compile interpreter to WAT, inject story data via text substitution:

```elixir
# Build time: Compile interpreter once
@core_wat Zorb.Interpreter.Core.to_wat()

# Runtime: Inject story data
def compile(story_data, opts) do
  {memory_init, globals, hash_table} = prepare_story_data(story_data)
  
  wat = inject_story_data(@core_wat, memory_init, globals, hash_table)
  wasm = Watusi.to_wasm(wat)
end
```

**Pros**: 
- Eliminates 83% of compilation time
- Simple implementation
- No Orb API changes needed

**Cons**:
- WAT text manipulation is fragile
- Loses type safety
- Harder to debug

#### Option 2: Orb Module Composition (Cleanest)

Use Orb's module system to compose pre-compiled core with story wrapper:

```elixir
defmodule Zorb.Interpreter.Core do
  use Orb
  # All interpreter logic here
  # Compiled once at build time
end

defmodule Zorb.Capsule.Bespoke_123 do
  use Orb
  
  # Import pre-compiled core
  Orb.Import.wasm(Zorb.Interpreter.Core)
  
  # Story-specific data
  Memory.initial_data!(0, u8: story_data)
  
  global do
    @globals_base 0x1234
    # ... other story constants
  end
end
```

**Pros**:
- Type-safe
- Clean API
- Maintainable

**Cons**:
- Requires Orb to support WASM imports (may not be implemented)
- More complex implementation

#### Option 3: Hybrid - Pre-compiled AST (Recommended)

Pre-compile interpreter to Elixir AST, inject story data at AST level:

```elixir
# Build time: Parse interpreter once
@interpreter_ast Sourceror.parse_string!(File.read!("interpreter.ex"))

# Runtime: Inject story data into AST
def assemble(story_data, module_name) do
  ast = @interpreter_ast
  
  # Fast AST transformations (only data injection)
  ast = inject_memory_data(ast, story_data)
  ast = inject_globals(ast, story_data)
  ast = inject_hash_table(ast, story_data)
  
  source = Sourceror.to_string(ast)
  {source, story_data}
end
```

**Pros**:
- Reduces AST manipulation (current bottleneck)
- Keeps existing architecture
- Type-safe
- Minimal changes

**Cons**:
- Still requires Elixir compilation (but faster)
- AST manipulation still needed

### Estimated Speedup

| Approach | Cold Compile | Speedup |
|----------|--------------|---------|
| Current | 4.24s | 1x |
| Option 1 (WAT) | ~500ms | **8.5x** |
| Option 2 (Orb) | ~800ms | **5.3x** |
| Option 3 (AST) | ~1.5s | **2.8x** |

### Recommendation

**Start with Option 3 (Hybrid AST)** because:
1. Minimal architecture changes
2. Keeps type safety
3. Reasonable speedup (2.8x)
4. Can upgrade to Option 1 later if needed

**Consider Option 1 (WAT Template)** if:
- Need maximum performance
- Willing to sacrifice some maintainability
- Can invest in robust WAT manipulation

**Avoid Option 2** unless:
- Orb adds proper WASM import support
- Need maximum type safety

## Implementation Plan

### Phase 1: Refactor Assembler (Low Risk)

1. Separate data preparation from AST manipulation
2. Minimize AST transformations
3. Cache intermediate results

**Expected speedup**: 1.2-1.5x

### Phase 2: Pre-compile AST (Medium Risk)

1. Move interpreter AST to compile-time
2. Inject only story-specific data
3. Optimize AST injection points

**Expected speedup**: 2.5-3x total

### Phase 3: WAT Template (High Risk, Optional)

1. Pre-compile to WAT
2. Implement WAT injection
3. Add validation

**Expected speedup**: 8-10x total

## Trade-offs

| Aspect | Current | Composable |
|--------|---------|------------|
| Cold compile | 4.24s | 0.5-1.5s |
| Cache hit | 454μs | 454μs |
| Maintainability | Good | Medium |
| Type safety | Full | Partial (WAT) |
| Debugging | Easy | Medium |
| Architecture | Simple | Complex |

## Decision Criteria

**Implement composable architecture if:**
- ✅ Cold compilation is a bottleneck for users
- ✅ Batch processing is common
- ✅ Cache is not sufficient

**Keep current architecture if:**
- ✅ Cache provides adequate performance (9,321x speedup)
- ✅ Simplicity is valued over speed
- ✅ Focus is on correctness (per AGENTS.md)

## Conclusion

**Composable architecture is feasible** and could provide 2.8-8.5x speedup for cold compilation. However, given that:

1. Cache already provides 9,321x speedup
2. Cold compilation is a one-time cost
3. Project focus is on correctness (AGENTS.md)

**Recommendation: Defer composable architecture** until cold compilation becomes a proven bottleneck for users. Current performance is acceptable.
