defmodule Zorb.V8GoldenTest do
  use ExUnit.Case, async: false
  @moduletag timeout: 600_000
  import Zorb.TestSupport.Expect
  alias Zorb.Runner

  @prover_dir Path.expand("../fixtures/provers", __DIR__)

  test "lostpig.z8 golden path" do
    prover_path = Path.join(@prover_dir, "lostpig.z8")
    owner = self()

    task = Task.async(fn -> Runner.run(prover_path, owner, timeout: 600_000) end)

    # Initial room
    expect(~r/Outside/i, 300_000, task.pid)
    expect(~r/Grunk think that pig probably go this way/i, 300_000, task.pid)

    # Move West
    answer(task.pid, "west
")
    expect(~r/Field/i, 300_000, task.pid)
    expect(~r/little stone wall/i, 300_000, task.pid)

    # Examine wall
    answer(task.pid, "examine wall
")
    expect(~r/It just little stone wall/i, 300_000, task.pid)

    # Move East (back to Outside)
    answer(task.pid, "east
")
    expect(~r/Outside/i, 300_000, task.pid)

    # Quit
    answer(task.pid, "quit
")
    expect(~r/Are you sure you want to quit/i, 300_000, task.pid)
    answer(task.pid, "y
")

    Task.await(task, 600_000)
  end
end
