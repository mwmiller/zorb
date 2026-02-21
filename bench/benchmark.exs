defmodule Zorb.Benchmark do
  @moduledoc """
  Performance benchmarking suite for Zorb.
  Run with: mix run bench/benchmark.exs
  """

  @prover_dir "test/fixtures/provers"

  def run do
    IO.puts("\n=== Zorb Performance Baseline ===\n")
    IO.puts("Compiler Version: #{Zorb.Capsule.compiler_version()}\n")

    stories = [
      {"zork1.z1", "V1 - Zork I"},
      {"zork1.z2", "V2 - Zork I"},
      {"zil_test.z3", "V3 - ZIL Test"},
      {"simple_test.z5", "V5 - Simple Test"},
      {"czech.z5", "V5 - Czech Prover"},
      {"strictz.z5", "V5 - StrictZ"},
      {"unicode.z5", "V5 - Unicode Test"},
      {"simple_test.z7", "V7 - Simple Test"},
      {"lostpig.z8", "V8 - Lost Pig"}
    ]

    IO.puts("## Compilation Performance (Cold - No Cache)\n")
    compile_results = benchmark_compilation(stories, cache: false)

    IO.puts("\n## Compilation Performance (Warm - First Cache Write)\n")
    first_cache_results = benchmark_compilation(stories, cache: true, clear_first: true)

    IO.puts("\n## Compilation Performance (Hot - Cache Hit)\n")
    cached_results = benchmark_compilation(stories, cache: true, clear_first: false)

    IO.puts("\n## WASM Size Analysis\n")
    size_analysis(stories)

    IO.puts("\n## Summary\n")
    print_summary(compile_results, first_cache_results, cached_results)
  end

  defp benchmark_compilation(stories, opts) do
    cache? = Keyword.get(opts, :cache, false)
    clear_first? = Keyword.get(opts, :clear_first, true)

    Enum.map(stories, fn {filename, label} ->
      path = Path.join(@prover_dir, filename)

      # Clear cache if requested
      if clear_first? do
        clear_cache_for(path)
      end

      # Check if cache exists before compilation
      cache_exists = cache? && cache_exists?(path)

      {time_us, wasm} = :timer.tc(fn -> Zorb.compile(path, cache: cache?) end)
      time_ms = time_us / 1000

      cache_indicator = if cache_exists, do: " [HIT]", else: ""
      IO.puts("#{String.pad_trailing(label, 25)} #{format_time(time_ms)} (#{format_bytes(byte_size(wasm))})#{cache_indicator}")

      {label, time_ms, byte_size(wasm)}
    end)
  end



  defp size_analysis(stories) do
    Enum.each(stories, fn {filename, label} ->
      path = Path.join(@prover_dir, filename)
      story_size = File.stat!(path).size
      wasm = Zorb.compile(path, cache: true)
      wasm_size = byte_size(wasm)
      ratio = Float.round(wasm_size / story_size, 2)

      IO.puts("#{String.pad_trailing(label, 25)} story: #{format_bytes(story_size)}, wasm: #{format_bytes(wasm_size)}, ratio: #{ratio}x")
    end)
  end

  defp print_summary(compile_results, first_cache_results, cached_results) do
    avg_cold = Enum.map(compile_results, fn {_, time, _} -> time end) |> average()
    avg_first_cache = Enum.map(first_cache_results, fn {_, time, _} -> time end) |> average()
    avg_hot = Enum.map(cached_results, fn {_, time, _} -> time end) |> average()

    IO.puts("Average cold compilation:        #{format_time(avg_cold)}")
    IO.puts("Average first cache (write):     #{format_time(avg_first_cache)}")
    IO.puts("Average hot compilation (read):  #{format_time(avg_hot)}")
    
    if avg_hot > 0 do
      IO.puts("Cache speedup:                   #{Float.round(avg_cold / avg_hot, 2)}x")
    end
  end

  defp clear_cache_for(path) do
    story_data = File.read!(path)
    hash = cache_hash(story_data)
    cache_path = Path.join(Zorb.Config.cache_dir(), "#{hash}.wasm")
    File.rm(cache_path)
  end

  defp cache_exists?(path) do
    story_data = File.read!(path)
    hash = cache_hash(story_data)
    cache_path = Path.join(Zorb.Config.cache_dir(), "#{hash}.wasm")
    File.exists?(cache_path)
  end

  defp cache_hash(story_data) do
    :crypto.hash(:sha256, [
      Zorb.Capsule.compiler_version(),
      Integer.to_string(byte_size(story_data)),
      story_data
    ])
    |> Base.encode16()
  end

  defp average([]), do: 0.0
  defp average(list), do: Enum.sum(list) / length(list)

  defp format_time(ms) when ms < 1, do: "#{Float.round(ms * 1000, 2)}μs"
  defp format_time(ms) when ms < 1000, do: "#{Float.round(ms, 2)}ms"
  defp format_time(ms), do: "#{Float.round(ms / 1000, 2)}s"

  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes}B"
  defp format_bytes(bytes) when bytes < 1024 * 1024, do: "#{Float.round(bytes / 1024, 2)}KB"
  defp format_bytes(bytes), do: "#{Float.round(bytes / (1024 * 1024), 2)}MB"
end

Zorb.Benchmark.run()
