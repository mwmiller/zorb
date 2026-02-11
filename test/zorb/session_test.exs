defmodule Zorb.SessionTest do
  use ExUnit.Case
  @moduletag timeout: 300_000

  alias Zorb.Session
  import Zorb.TestSupport.Expect

  @prover_dir "test/fixtures/provers"

  test "starts a session and handles input/output with zil_test" do
    prover_path = Path.join(@prover_dir, "zil_test.z3")

    # Start session, notify us
    {:ok, pid} = Session.start_link(prover_path, notify_to: self())

    # Should print the initial room
    expect(~r/A TEST FILE/i, 120_000, pid)
    expect(~r/TESTING LAB/i, 120_000, pid)

    # Send some input
    Session.send_input(pid, "quit\n")

    # Should see more output
    expect(~r/Are you sure you want to quit/i, 120_000, pid)

    # Clean up
    Process.monitor(pid)
    if Process.alive?(pid), do: GenServer.stop(pid)

    receive do
      {:DOWN, _, :process, ^pid, _} -> :ok
    after
      # It might have already exited
      5000 -> :ok
    end
  end

  test "handles halt correctly with czech" do
    prover_path = Path.join(@prover_dir, "czech.z5")

    {:ok, pid} = Session.start_link(prover_path, notify_to: self())
    ref = Process.monitor(pid)

    # Should print header
    expect("CZECH:", 120_000, pid)

    # We'll just stop it and ensure it halts gracefully
    if Process.alive?(pid), do: GenServer.stop(pid)

    receive do
      {:DOWN, ^ref, :process, ^pid, _reason} -> :ok
    after
      5000 -> :ok
    end
  end
end
