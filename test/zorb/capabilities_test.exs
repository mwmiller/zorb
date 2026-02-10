defmodule Zorb.CapabilitiesTest do
  use ExUnit.Case, async: false
  @moduletag timeout: 600_000
  import Zorb.TestSupport.Expect
  alias Zorb.Runner

  @prover_dir Path.expand("../fixtures/provers", __DIR__)

  test "lostpig.z8 reflects host capabilities in Flags 2" do
    prover_path = Path.join(@prover_dir, "lostpig.z8")

    # Test with minimal capabilities
    task =
      Task.async(fn ->
        Runner.run(prover_path, self(),
          imports: %{
            "zio" => %{
              "get_capabilities" => {:fn, [], [:i32], fn _ctx -> 0x02 end}
            }
          }
        )
      end)

    answer_on(~r/Are you sure you want to quit/i, "y\n", task_pid: task.pid)
    answer_on(~r/>/i, "quit\n", task_pid: task.pid)

    expect(~r/Are you sure you want to quit/i, 300_000, task.pid)

    Task.await(task, 600_000)
  end
end
