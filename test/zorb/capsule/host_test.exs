defmodule Zorb.Capsule.HostTest do
  use ExUnit.Case
  @moduletag timeout: 300_000

  alias Zorb.Runner
  import Zorb.TestSupport.Expect

  @prover_dir "test/fixtures/provers"

  test "handles host with zero capabilities gracefully" do
    prover_path = Path.join(@prover_dir, "czech.z5")

    # Manually trigger compilation to see if it hangs here in the main test process
    _wat = Zorb.Capsule.compile(prover_path)

    # Override get_capabilities to return 0 (no status line, no splits, etc)
    opts = [
      imports: %{
        "zio" => %{
          "get_capabilities" => {:fn, [], [:i32], fn _ctx -> 0 end}
        }
      }
    ]

    parent = self()
    pid = spawn_link(fn -> Runner.run(prover_path, parent, opts) end)

    # Game should still boot and print basics
    expect("CZECH: the Comprehensive Z-machine Emulation CHecker", 120_000, pid)
    answer(pid, "\n")

    # Wait for the process to exit
    ref = Process.monitor(pid)

    receive do
      {:DOWN, ^ref, :process, ^pid, _reason} -> :ok
    after
      120_000 -> flunk("Runner timed out")
    end
  end
end
