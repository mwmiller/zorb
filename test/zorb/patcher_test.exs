defmodule Zorb.PatcherTest do
  use ExUnit.Case, async: true

  @story_path "test/fixtures/provers/etude.z5"

  test "patcher produces working WASM" do
    wasm = Zorb.Patcher.compile(@story_path)

    # Verify it's valid WASM
    assert byte_size(wasm) > 0
    # WASM magic number
    assert binary_part(wasm, 0, 4) == <<0x00, 0x61, 0x73, 0x6D>>
  end

  test "patcher is much faster than traditional compilation" do
    # Warm up
    Zorb.Patcher.compile(@story_path)

    # Time patcher
    {patcher_time, _} = :timer.tc(fn -> Zorb.Patcher.compile(@story_path) end)

    # Time traditional (just once, it's slow)
    {traditional_time, _} =
      :timer.tc(fn -> Zorb.Capsule.compile(@story_path, method: :traditional) end)

    patcher_ms = patcher_time / 1000
    traditional_ms = traditional_time / 1000
    speedup = traditional_ms / patcher_ms

    IO.puts("\nPatcher: #{Float.round(patcher_ms, 1)}ms")
    IO.puts("Traditional: #{Float.round(traditional_ms, 1)}ms")
    IO.puts("Speedup: #{Float.round(speedup, 1)}x")

    # Patcher should be at least 10x faster
    assert speedup > 10
  end
end
