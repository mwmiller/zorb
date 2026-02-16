defmodule ZorbTest do
  use ExUnit.Case
  import Zorb.TestSupport.Expect

  @story_path "test/fixtures/provers/simple_test.z5"

  test "compile/2 generates WASM data" do
    wasm = Zorb.compile(@story_path)
    assert is_binary(wasm)
    assert String.starts_with?(wasm, <<0, 97, 115, 109>>)
  end

  test "run/2 starts a session and produces output" do
    {:ok, pid} = Zorb.run(@story_path, notify_to: self())
    assert is_pid(pid)

    # simple_test.z5 prints "Simple Test" and then a prompt or something.
    # We'll just check it produces some output and eventually halts.
    expect(~r/units 0 by 0/i, 10_000, pid)

    # Clean up
    GenServer.stop(pid)
  end

  test "run/2 with cache: true" do
    # First run to populate cache
    wasm1 = Zorb.compile(@story_path, cache: true)

    {:ok, pid} = Zorb.run(@story_path, notify_to: self(), cache: true)
    assert is_pid(pid)
    expect(~r/units 0 by 0/i, 10_000, pid)
    GenServer.stop(pid)

    # Second run should be faster/identical
    wasm2 = Zorb.compile(@story_path, cache: true)
    assert wasm1 == wasm2
  end
end
