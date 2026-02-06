## Resolved (February 6, 2026)
The "garbage" issue was caused by **dictionary pruning** in `Zorb.Capsule.Assembler`. 

When the Z-machine logic (running in WASM) encounters an error or needs to display a word, it often refers back to the dictionary entry using the `dict_addr` provided in the parse buffer. Because the assembler was zeroing out the dictionary area to save memory, the game was reading zeros, which it then misinterpreted as garbage or empty text.

Disabling the `prune_story_data` logic (or rather, making it a NOP) fixed the issue, allowing V1 and V2 games (like Zork 1) to correctly display error messages and handle commands.

## Current Status
- Dictionary lookups work.
- Words are recognized.
- Error messages display the correct words.
- Zork 1 is fully playable in V1 and V2.

## Next Steps
- Re-evaluate if any memory pruning is actually safe, or if we should just keep the full story data intact for compatibility.
- Consider if we can selectively prune only truly unreachable data (e.g. padding).

## Investigation Done

### Text Buffer Format (V2)
```
buf[0] = max_length (e.g., 80)
buf[1..] = text characters (for V1-4, st=1)
```

For "quit":
```
buf[0] = 80
buf[1] = 'q'
buf[2] = 'u'
buf[3] = 'i'
buf[4] = 't'
buf[5] = 0 (null terminator)
buf[6..80] = 0 (cleared)
```

### Parse Buffer Format
```
parse[0] = max_words (e.g., 20)
parse[1] = word_count (written by tokenizer)
parse[2+n*4..2+n*4+3] = entry n:
  [0-1]: dict_addr (16-bit big-endian)
  [2]: word_len (byte)
  [3]: word_offset (byte)
```

For "quit":
```
parse[0] = 20
parse[1] = 1
parse[2-3] = dict_addr for "quit"
parse[4] = 4 (word_len)
parse[5] = 1 (word_offset)
```

### Word Offset Calculation
```elixir
word_offset = word_start + (version >= 5 ? 2 : 1)
```

For V2 with word at start of text:
- `word_start = 0` (first char in text area)
- `word_offset = 0 + 1 = 1`
- Points to `buf[1]` = 'q' ✓

This should be correct!

### Dictionary Lookup Flow
1. Tokenizer reads text from `buf + st` (st=1 for V2)
2. Extracts word "quit"
3. Encodes to z-chars: w1, w2, w3
4. Calls `ldict(w1, w2, w3)`:
   - Calculates hash slot
   - Looks in hash table at 0x82000
   - Finds match
   - Returns dict_addr from story file
5. Writes parse buffer entry with dict_addr, len=4, offset=1

### What the Game Does
1. Reads `parse[1]` = word_count = 1
2. Reads entry at `parse[2-5]`:
   - dict_addr = address of "quit" in dictionary ✓
   - word_len = 4 ✓
   - word_offset = 1 ✓
3. Looks up dict_addr in dictionary → recognizes word ✓
4. Decides "quit" is not valid here
5. To display error, reads from text buffer:
   - Starts at: `text_buf[word_offset]` = `text_buf[1]`
   - Reads `word_len` bytes = 4 bytes
   - SHOULD get: "quit"
   - ACTUALLY gets: garbage "c   I4"

## Hypotheses Tested

### ❌ Parse buffer clearing
- Added clearing of remaining slots after valid entries
- Did not fix issue

### ❌ Text buffer clearing
- Added loop to clear text buffer after input
- Did not fix issue

### ❌ Byte order swap
- Tried swapping word_len and word_offset in parse buffer
- Made garbage different but didn't fix it

### ❌ Dictionary lookup issue
- Fixed hash table format to use (w1 << 16) | w2
- Fixed mdict comparison
- Words ARE being found now

## Current Status
- Dictionary lookups work (test passing)
- Words are recognized (not "I don't know the word")
- But game displays garbage when showing word in error message
- The garbage pattern is consistent: starts with 'c', includes spaces

## Possible Root Causes

### 1. Text Buffer Layout Issue
Maybe the game expects text to be laid out differently than we're storing it?
- Could buf+1 be wrong for V2?
- Could there be padding or alignment issues?

### 2. Word Offset Interpretation
Maybe word_offset is NOT an absolute buffer address but relative to something else?
- Relative to buf+1 instead of buf?
- Relative to some other base address?

### 3. Parse Buffer Format Mismatch
Maybe some versions use different parse buffer format?
- Different byte order?
- Different field meanings?

### 4. Memory Corruption
Maybe something is overwriting the text buffer after tokenization?
- Between tokenize and game reading it?
- During dictionary lookup?

### 5. WASM Memory Issue
Maybe WASM memory alignment or access pattern issue?
- Reading across page boundaries?
- Cache coherency issue?

## Next Steps for Debugging

1. **Memory Dump**: Add logging to dump actual memory contents of:
   - Text buffer before and after tokenize
   - Parse buffer after tokenize
   - Text buffer when game tries to read word

2. **Compare with Reference**: Run Frotz or other interpreter on same story:
   - Capture parse buffer format
   - See what word_offset values it uses

3. **Test with Simple Command**: Try a single-letter command to minimize variables

4. **Check Other Versions**: Test V1, V3, V5 to see if pattern differs

5. **Trace Game Code**: Disassemble the game's error message routine to see exactly how it reads the word

## Files Changed
- `lib/zorb/capsule/assembler.ex`: Hash table generation, WASM tokenizer
- `lib/zorb/interpreter.ex`: Text buffer clearing, alphabet decoding, ZSCII escape

## Tests Passing
- ✅ All assembler tests including hash table generation
- ✅ Text display correct for V1 and V2
- ❌ Story integration (parse buffer garbage)
