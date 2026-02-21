# Composable Interpreter - Executive Summary

## Answer: Yes, We Can Build It in Composable Pieces

**Potential speedup: 26.7x for single story, 8.3x for batch processing**

## Current Architecture

```
Story File → Assembler → Elixir Compile → WAT → WASM
             (489ms)     (3.44s - 87%)    (250ms)
```

**Problem**: The entire interpreter (2,763 lines) is recompiled for each story, even though the logic is identical.

## Composable Architecture

```
Build Time:
  Interpreter → Elixir Compile → WAT Template
                (3.26s - one time)

Runtime (per story):
  Story File → Data Prep → Inject into WAT → WASM
               (147ms)     (fast)            (118ms)
```

**Benefit**: Interpreter compiled once, story data injected quickly.

## Performance Comparison

| Scenario | Current | Composable | Speedup |
|----------|---------|------------|---------|
| Single story (cold) | 3.93s | 147ms* | **26.7x** |
| 10 stories (batch) | 39.3s | 4.73s | **8.3x** |
| With cache (hot) | 454μs | 454μs | 1x |

*After one-time 3.26s pre-compile

## Implementation Options

### Option 1: WAT Template Injection (Recommended)

**How it works:**
1. Pre-compile interpreter to WAT at build time
2. At runtime, inject story data via string substitution
3. Convert WAT to WASM

**Pros:**
- Maximum speedup (26.7x)
- Simple implementation
- No Orb API changes

**Cons:**
- WAT manipulation is fragile
- Loses some type safety

**Estimated effort:** 2-3 days

### Option 2: Modular Orb (If Orb Supports It)

**How it works:**
1. Compile interpreter as separate WASM module
2. Import interpreter functions into story module
3. Link at WASM level

**Pros:**
- Clean architecture
- Type-safe
- Maintainable

**Cons:**
- Requires Orb WASM import support (may not exist)
- More complex

**Estimated effort:** 1-2 weeks (if Orb supports it)

### Option 3: Optimized AST (Incremental)

**How it works:**
1. Cache parsed interpreter AST
2. Minimize AST transformations
3. Inject only story-specific nodes

**Pros:**
- Lower risk
- Incremental improvement
- Keeps existing architecture

**Cons:**
- Smaller speedup (2-3x)
- Still requires Elixir compilation

**Estimated effort:** 3-5 days

## Recommendation

### For Immediate Impact: Implement Option 1 (WAT Template)

**Why:**
- 26.7x speedup is significant
- Relatively simple to implement
- Solves the 87% bottleneck (Elixir compilation)
- Cache still works for repeated compilations

**When to implement:**
- If users are batch-compiling many stories
- If cold compilation time is a pain point
- If you want maximum performance

### Alternative: Keep Current Architecture

**Why:**
- Cache already provides 9,321x speedup for repeated compilations
- Cold compilation is a one-time cost
- Current architecture is simple and maintainable
- Project focus is on correctness (per AGENTS.md)

**When to keep current:**
- If cache is sufficient for most use cases
- If simplicity is valued over speed
- If cold compilation isn't a bottleneck for users

## Implementation Sketch (Option 1)

```elixir
defmodule Zorb.Capsule.Composable do
  # Build time: Pre-compile interpreter to WAT
  @core_wat compile_interpreter_to_wat()
  
  defp compile_interpreter_to_wat do
    # Compile a "template" interpreter with placeholder values
    template_story = create_template_story()
    module_name = Zorb.Interpreter.Core
    
    {source, _} = Zorb.Capsule.Assembler.assemble(template_story, module_name)
    Code.compile_string(source)
    
    Orb.to_wat(module_name)
  end
  
  # Runtime: Inject story data into WAT template
  def compile(story_path, opts) do
    story_data = File.read!(story_path)
    
    if Keyword.get(opts, :cache, false) do
      # Cache still works
      case load_from_cache(story_data) do
        {:ok, wasm} -> wasm
        :error ->
          wasm = compile_with_injection(story_data)
          save_to_cache(story_data, wasm)
          wasm
      end
    else
      compile_with_injection(story_data)
    end
  end
  
  defp compile_with_injection(story_data) do
    # Fast: Just data preparation
    {memory_init, globals, hash_table} = prepare_story_data(story_data)
    
    # Fast: String substitution in WAT
    wat = @core_wat
    |> inject_memory(memory_init)
    |> inject_globals(globals)
    |> inject_hash_table(hash_table)
    
    # Fast: WAT to WASM
    Watusi.to_wasm(wat)
  end
end
```

## Trade-offs

| Aspect | Current | Composable |
|--------|---------|------------|
| Cold compile | 3.93s | 147ms |
| Cache hit | 454μs | 454μs |
| Maintainability | ★★★★★ | ★★★☆☆ |
| Type safety | ★★★★★ | ★★★☆☆ |
| Complexity | ★★☆☆☆ | ★★★★☆ |
| Debugging | ★★★★★ | ★★★☆☆ |

## Conclusion

**Yes, composable architecture is feasible and would provide significant speedup (26.7x).**

However, the decision to implement depends on:
- Whether cold compilation is a bottleneck for users
- Whether the complexity trade-off is acceptable
- Whether the project is ready to move beyond correctness focus

**Recommendation**: Gather user feedback on cold compilation performance before implementing. If it's a pain point, Option 1 (WAT Template) provides the best ROI.
