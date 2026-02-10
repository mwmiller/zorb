# Z-Machine Tracing and Debugging Guide

Tracing the Z-machine's execution state is essential for diagnosing hangs, infinite loops, and instruction-level bugs. This guide documents the established patterns for tracing within the Zorb environment.

## 1. Instruction-Level Tracing

To see every opcode and Program Counter (PC) as it executes, use the `log_step` Host import.

### Enable Tracing in WASM (`Interpreter`)
In `lib/zorb/interpreter.ex`, add a call to `log_step` at the start of the `step()` function:

```elixir
defw step(), nil, ... do
  @tick = I32.add(@tick, 1)
  b = fetch_byte()
  # credo:disable-for-next-line Credo.Check.Design.AliasUsage
  Zorb.Capsule.Host.log_step(@tick, I32.sub(@pc, 1), b)
  ...
end
```

### Handle Tracing in Host (`Runner`)
In `lib/zorb/runner.ex`, implement `log_step_impl` to output the trace data:

```elixir
defp log_step_impl(_agent) do
  fn _ctx, tick, pc, opcode ->
    IO.puts(:stderr, "Zorb: Step #{tick}: PC=0x#{Integer.to_string(pc, 16)} Op=0x#{Integer.to_string(opcode, 16)}")
    nil
  end
end
```

## 2. Granular Step Execution

For debugging specific sequences, reduce the `run_steps` chunk size in `lib/zorb/runner.ex`. Running 1 step at a time provides the highest granularity.

```elixir
# lib/zorb/runner.ex
defp loop(instance, agent, steps) do
  ...
  chunk = 1 # Execute 1 step per WASM call
  case Wasmex.call_function(instance, "run_steps", [chunk], timeout) do
    {:ok, _} -> loop(instance, agent, steps + chunk)
    ...
  end
end
```

## 3. Host Interface Logging

Hangs often occur during I/O. Add logging to the `zio` namespace implementations in `lib/zorb/runner.ex` to track interaction points.

*   **`read_char`**: Log when the Z-machine is waiting for user input.
*   **`print_char`**: Log output to see real-time progress before the buffer is flushed.
*   **`halt`**: Always log the reason and PC when the machine stops.

## 4. Identifying Infinite Loops

If the machine hangs without I/O, it is likely in an infinite loop. Use prime-numbered sampling to detect patterns without syncing with the loop period.

```elixir
# Every 719 steps, sample the current PC
case Wasmex.call_function(instance, "run_steps", [719], timeout) do
  {:ok, _} ->
    {:ok, [pc]} = Wasmex.call_function(instance, "get_pc", [])
    IO.puts(:stderr, "Zorb: Sample PC=0x#{Integer.to_string(pc, 16)}")
    ...
end
```

## 5. Bypassing the Compilation Cache

When modifying `lib/zorb/interpreter.ex`, ensure you aren't running a cached WASM module.

1.  **Unique Module Names**: Add a timestamp or iteration ID to the `module_name` in `lib/zorb/capsule.ex`.
2.  **Clear Cache**: Use `rm -rf tmp/zorb_cache/*` between runs.

## 6. Execution Trace Example

A typical "Recognition Loop" failure in a prover looks like this:

```
Zorb: Host call: read_char() called
Zorb: Host call: wait_for_input returning ZSCII 78 ('N')
...
Zorb: Step 33: PC=0x97F Op=0xCD  # Dictionary lookup
Zorb: Step 34: PC=0x984 Op=0xE2  # Tokenize
Zorb: Step 35: PC=0x989 Op=0xE4  # aread (loops back if word not recognized)
```

By cross-referencing these PC values with a `hexdump -C` of the story file, you can identify which instruction is failing its condition.
