# Proof of Concept: Composable Interpreter
# This demonstrates the potential speedup from separating compilation stages

defmodule ComposablePOC do
  @test_story "test/fixtures/provers/simple_test.z5"

  def run do
    IO.puts("\n=== Composable Interpreter POC ===\n")

    story_data = File.read!(@test_story)
    
    # Measure each stage separately
    IO.puts("## Current Pipeline Breakdown")
    
    {t_assemble, {source, _}} = :timer.tc(fn ->
      unique = :erlang.unique_integer([:positive])
      module_name = Module.concat([Zorb, Capsule, "POC_#{unique}"])
      Zorb.Capsule.Assembler.assemble(story_data, module_name)
    end)
    IO.puts("  Assembler:       #{format_time(t_assemble / 1000)}")
    
    {t_compile, _} = :timer.tc(fn ->
      Code.compile_string(source)
    end)
    IO.puts("  Elixir Compile:  #{format_time(t_compile / 1000)}")
    
    total = t_assemble + t_compile
    IO.puts("  Total:           #{format_time(total / 1000)}\n")

    # Estimate composable approach
    IO.puts("## Estimated Composable Approach")
    
    # Pre-compile would be one-time
    precompile_time = t_compile * 0.95  # Most of compile time
    IO.puts("  Pre-compile (one-time): #{format_time(precompile_time / 1000)}")
    
    # Per-story would be data prep + injection
    per_story_time = t_assemble * 0.3  # Just data prep, no AST manipulation
    IO.puts("  Per-story injection:    #{format_time(per_story_time / 1000)}\n")

    # Single story comparison
    IO.puts("## Single Story")
    IO.puts("  Current:     #{format_time(total / 1000)}")
    IO.puts("  Composable:  #{format_time(per_story_time / 1000)} (after one-time pre-compile)")
    IO.puts("  Speedup:     #{Float.round(total / per_story_time, 2)}x\n")

    # Batch comparison (10 stories)
    IO.puts("## Batch (10 stories)")
    current_batch = total * 10
    composable_batch = precompile_time + (per_story_time * 10)
    
    IO.puts("  Current:     #{format_time(current_batch / 1000)}")
    IO.puts("  Composable:  #{format_time(composable_batch / 1000)}")
    IO.puts("  Speedup:     #{Float.round(current_batch / composable_batch, 2)}x\n")

    IO.puts("## Conclusion")
    IO.puts("  Composable architecture could provide:")
    IO.puts("  - #{Float.round(total / per_story_time, 1)}x speedup for single story (after pre-compile)")
    IO.puts("  - #{Float.round(current_batch / composable_batch, 1)}x speedup for batch processing")
    IO.puts("  - One-time pre-compile cost: #{format_time(precompile_time / 1000)}")
  end

  defp format_time(ms) when ms < 1, do: "#{Float.round(ms * 1000, 2)}μs"
  defp format_time(ms) when ms < 1000, do: "#{Float.round(ms, 2)}ms"
  defp format_time(ms), do: "#{Float.round(ms / 1000, 2)}s"
end

ComposablePOC.run()
