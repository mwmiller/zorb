# Pruning Impact Analysis

**Date**: February 21, 2026  
**Comparison**: Before vs After Version Branch Pruning (COMPLETE)

## WASM Size Comparison

| Story | Before | After | Reduction | % Saved |
|-------|--------|-------|-----------|---------|
| V1 - Zork I | 130.01KB | 128.48KB | **1.53KB** | 1.18% |
| V2 - Zork I | 125.73KB | 124.22KB | **1.51KB** | 1.20% |
| V3 - ZIL Test | 71.72KB | 70.22KB | **1.50KB** | 2.09% |
| V5 - Simple Test | 52.35KB | 51.01KB | **1.34KB** | 2.56% |
| V5 - Czech Prover | 61.88KB | 60.53KB | **1.35KB** | 2.18% |
| V5 - StrictZ | 52.85KB | 51.51KB | **1.34KB** | 2.54% |
| V5 - Unicode Test | 53.36KB | 52.01KB | **1.35KB** | 2.53% |
| V7 - Simple Test | 52.35KB | 51.01KB | **1.34KB** | 2.56% |
| V8 - Lost Pig | 327.89KB | 326.55KB | **1.34KB** | 0.41% |

**Average Reduction**: 1.40KB per capsule (1.92% average)

## Version Check Elimination

| Metric | Before | After | Result |
|--------|--------|-------|--------|
| Interpreter checks | 45 | 0 | **100% eliminated** ✅ |
| Injected AST checks | ~32 | 0 | **100% eliminated** ✅ |
| Total checks | ~77 | 0 | **100% eliminated** ✅ |

## Analysis

### Complete Elimination

The pruning now achieves **100% elimination** of version checks by:

1. **Pruning the interpreter AST** - All version checks in the main interpreter code
2. **Pruning injected ASTs** - Tokenizer, dictionary, and helper functions generated at compile-time

### Why 1.4KB?

The consistent ~1.4KB reduction represents:
- All version-checking conditional logic (~45 checks in interpreter)
- All version-checking in tokenizer (~32 checks in do_tokenise)
- Branch code that can never execute for the target version

### Size Impact by Story Type

- **Small stories** (3.5-4.5KB): 2.5% reduction - highest percentage impact
- **Medium stories** (13-23KB): 2.1-2.2% reduction  
- **Large stories** (76-278KB): 0.4-1.2% reduction - smallest percentage but same absolute savings

The absolute reduction (~1.4KB) is consistent because it represents the fixed interpreter overhead. The percentage varies based on story data size.

## Implementation

**Key Changes:**
1. Prune main interpreter AST after loading from Sourceror
2. Prune `ldict_definition_ast` after quote generation
3. Prune `mdict_definition_ast` after quote generation  
4. Prune `do_tokenise_definition_ast` after quote generation

All injected ASTs are now pruned before injection, ensuring zero version checks in the final capsule.

## Conclusion

Version branch pruning delivers:

✅ **100% version check elimination** - Zero runtime checks  
✅ **1.4KB average size reduction** per capsule (1.92%)  
✅ **True bespoke optimization** - Each story contains only its version's code  
✅ **Cleaner generated code** - No dead branches  

The pruning is now **complete and production-ready**. Every version check has been eliminated, and each capsule contains only the code paths that can execute for its specific Z-machine version.
