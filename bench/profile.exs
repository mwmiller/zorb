defmodule Zorb.Profile do
  @moduledoc """
  Detailed profiling of the Zorb compilation pipeline.
  Run with: mix run bench/profile.exs
  """

  @test_story "test/fixtures/provers/simple_test.z5"

  def run do
    IO.puts("\n=== Zorb Compilation Pipeline Profile ===\n")
    IO.puts("Story: #{@test_story}")
    IO.puts("Story size: #{format_bytes(File.stat!(@test_story).size)}\n")

    # Profile each stage
    story_data = File.read!(@test_story)
    
    IO.puts("## Stage 1: Story File I/O")
    {t_read, _} = :timer.tc(fn -> File.read!(@test_story) end)
    IO.puts("  File.read!: #{format_time(t_read / 1000)}\n")

    IO.puts("## Stage 2: Assembler (AST-based)")
    unique = :erlang.unique_integer([:positive])
    module_name = Module.concat([Zorb, Capsule, "Profile_#{unique}"])

    {t_assemble, ast} = :timer.tc(fn ->
      Zorb.Capsule.Assembler.assemble(story_data, module_name)
    end)
    IO.puts("  Assembler.assemble: #{format_time(t_assemble / 1000)}\n")

    IO.puts("## Stage 3: Elixir Compilation")
    {t_compile, _} = :timer.tc(fn -> Code.eval_quoted(ast, [], __ENV__) end)
    IO.puts("  Code.eval_quoted: #{format_time(t_compile / 1000)}\n")

    IO.puts("## Stage 4: WAT Generation")
    {t_wat, wat} = :timer.tc(fn -> Orb.to_wat(module_name) end)
    IO.puts("  Orb.to_wat: #{format_time(t_wat / 1000)}")
    IO.puts("  WAT size: #{format_bytes(byte_size(wat))}\n")

    IO.puts("## Stage 5: WASM Binary Generation")
    {t_wasm, wasm} = :timer.tc(fn -> Watusi.to_wasm(wat) end)
    IO.puts("  Watusi.to_wasm: #{format_time(t_wasm / 1000)}")
    IO.puts("  WASM size: #{format_bytes(byte_size(wasm))}\n")

    IO.puts("## Stage 6: Cache Operations")
    hash = cache_hash(story_data)
    cache_path = Path.join(Zorb.Config.cache_dir(), "#{hash}.wasm")
    
    {t_write, _} = :timer.tc(fn -> 
      File.mkdir_p!(Zorb.Config.cache_dir())
      File.write!(cache_path, wasm)
    end)
    IO.puts("  Cache write: #{format_time(t_write / 1000)}")
    
    {t_read_cache, _} = :timer.tc(fn -> File.read!(cache_path) end)
    IO.puts("  Cache read: #{format_time(t_read_cache / 1000)}\n")

    # Total
    total = t_read + t_assemble + t_compile + t_wat + t_wasm + t_write
    IO.puts("## Total Pipeline Time: #{format_time(total / 1000)}\n")

    # Breakdown
    IO.puts("## Time Breakdown")
    stages = [
      {"File I/O", t_read},
      {"Assembler", t_assemble},
      {"Elixir Compile", t_compile},
      {"WAT Generation", t_wat},
      {"WASM Generation", t_wasm},
      {"Cache Write", t_write}
    ]

    Enum.each(stages, fn {name, time} ->
      pct = Float.round(time / total * 100, 1)
      IO.puts("  #{String.pad_trailing(name, 20)} #{format_time(time / 1000)} (#{pct}%)")
    end)

    IO.puts("\n## Optimization Opportunities")
    
    # Find the slowest stage
    {slowest_name, slowest_time} = Enum.max_by(stages, fn {_, time} -> time end)
    slowest_pct = Float.round(slowest_time / total * 100, 1)
    
    IO.puts("  Slowest stage: #{slowest_name} (#{slowest_pct}%)")
    IO.puts("  Potential speedup if eliminated: #{Float.round(total / (total - slowest_time), 2)}x")
    
    # Check if any stage is > 40%
    bottlenecks = Enum.filter(stages, fn {_, time} -> time / total > 0.4 end)
    if length(bottlenecks) > 0 do
      IO.puts("\n  Major bottlenecks (>40% of time):")
      Enum.each(bottlenecks, fn {name, _} ->
        IO.puts("    - #{name}")
      end)
    end
  end

  defp cache_hash(story_data) do
    :crypto.hash(:sha256, [
      Zorb.Capsule.compiler_version(),
      Integer.to_string(byte_size(story_data)),
      story_data
    ])
    |> Base.encode16()
  end

  defp format_time(ms) when ms < 1, do: "#{Float.round(ms * 1000, 2)}μs"
  defp format_time(ms) when ms < 1000, do: "#{Float.round(ms, 2)}ms"
  defp format_time(ms), do: "#{Float.round(ms / 1000, 2)}s"

  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes}B"
  defp format_bytes(bytes) when bytes < 1024 * 1024, do: "#{Float.round(bytes / 1024, 2)}KB"
  defp format_bytes(bytes), do: "#{Float.round(bytes / (1024 * 1024), 2)}MB"
end

Zorb.Profile.run()
