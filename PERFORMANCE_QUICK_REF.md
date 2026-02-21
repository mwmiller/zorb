# Performance Baseline - Quick Reference

## Current Performance (v0.8.0)

| Metric | Value |
|--------|-------|
| Cold compilation | 4.24s avg |
| Hot compilation (cache hit) | 454μs avg |
| Cache speedup | **9,321x** |
| WASM size overhead | 50KB baseline + story data |

## Bottleneck Analysis

```
Elixir Compile:  ████████████████████████████████████████ 83.3% (4.81s)
Assembler:       ██████                                    12.3% (712ms)
WAT Generation:  █                                          2.3% (132ms)
WASM Generation: █                                          2.0% (118ms)
Other:           ▏                                          0.1% (1ms)
```

## Recommendations

✅ **Always use cache in production**
```elixir
Zorb.compile("story.z5", cache: true)
```

✅ **Parallel compilation for multiple stories**
```elixir
Task.async_stream(stories, &Zorb.compile(&1, cache: true))
```

❌ **Don't optimize cold compilation** - Not worth the complexity

## Running Benchmarks

```bash
# Full benchmark
mix run bench/benchmark.exs

# Detailed profiling
mix run bench/profile.exs
```

## Test Results

✅ All 30 tests pass  
✅ No correctness issues  
✅ V1-V8 support verified (excluding V6)
