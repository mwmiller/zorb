defmodule Zorb.Capsule.HostTest do
  use ExUnit.Case
  @moduletag timeout: 300_000

  import Zorb.TestSupport.Expect

  @prover_dir "test/fixtures/provers"

  test "handles host with zero capabilities gracefully" do
    prover_path = Path.join(@prover_dir, "czech.z5")

    # Override get_capabilities to return 0 (no status line, no splits, etc)
    opts = [
      notify_to: self(),
      imports: %{
        "zio" => %{
          "get_capabilities" => {:fn, [], [:i32], fn _ctx -> 0 end}
        }
      }
    ]

    {:ok, pid} = Zorb.Session.start_link(prover_path, opts)

    # Game should still boot and print basics
    expect("CZECH: the Comprehensive Z-machine Emulation CHecker", 120_000, pid)
    answer(pid, "\n")

    # Wait for the process to exit
    ref = Process.monitor(pid)

    receive do
      {:DOWN, ^ref, :process, ^pid, _reason} -> :ok
    after
      120_000 -> flunk("Session timed out")
    end
  end
end
