defmodule Zorb.Capsule.HostTest do
  use ExUnit.Case
  alias Zorb.Runner
  import Zorb.TestSupport.Expect

  @prover_dir "test/fixtures/provers"

  test "handles host with zero capabilities gracefully" do
    prover_path = Path.join(@prover_dir, "simple_test.z5")
    owner = self()

    # Override get_capabilities to return 0 (no status line, no splits, etc)
    opts = [
      imports: %{
        "zio" => %{
          "get_capabilities" => {:fn, [], [:i32], fn _ctx -> 0 end}
        }
      }
    ]

    task = Task.async(fn -> Runner.run(prover_path, owner, opts) end)

    # Game should still boot and print basics
    expect("units 0 by 0", 5000, task.pid)
    answer(task.pid, "quit
")

    Task.await(task, 60_000)
  end
end
