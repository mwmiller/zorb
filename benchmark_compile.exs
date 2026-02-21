#!/usr/bin/env elixir

# Benchmark script to profile compilation time
# Usage: mix run benchmark_compile.exs

Logger.configure(level: :debug)

story_files = [
  "test/fixtures/provers/zork1.z1",
  "test/fixtures/provers/zil_test.z3",
  "test/fixtures/provers/etude.z5"
]

for story <- story_files do
  if File.exists?(story) do
    IO.puts("\n=== Compiling #{Path.basename(story)} ===")
    Zorb.Capsule.compile(story)
  else
    IO.puts("Skipping #{story} (not found)")
  end
end
