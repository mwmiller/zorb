defmodule Zorb.ProverTest do
  use ExUnit.Case

  alias Zorb.Runner
  import Zorb.TestSupport.Expect

  @prover_dir "test/fixtures/provers"

  setup do
    Process.put(:zorb_disputes, [])
    Process.put(:zorb_answers, [])
    :ok
  end

  @tag :skip
  test "czech.z5 prover integration" do
    prover_path = Path.join(@prover_dir, "czech.z5")
    owner = self()

    task = Task.async(fn -> Runner.run(prover_path, owner) end)

    dispute("ERROR")
    dispute("bad")

    expect("CZECH: the Comprehensive Z-machine Emulation CHecker", 5000, task.pid)
    # Czech runs through many tests. We'll wait for the summary.
    # We expect 0 failures.
    expect(~r/Passed: \d+, Failed: 0/, 60_000, task.pid)

    # Prover usually waits for a final key
    answer(task.pid, "\n")

    Task.await(task)
  end

  @tag :skip
  test "strictz.z5 prover integration" do
    prover_path = Path.join(@prover_dir, "strictz.z5")
    owner = self()

    task = Task.async(fn -> Runner.run(prover_path, owner) end)

    expect("Strict Z Test", 5000, task.pid)
    expect("Would you like to make a transcript of the test results? (Y/N)", 5000, task.pid)
    answer(task.pid, "n")

    expect("Test completed!", 60_000, task.pid)

    # Prover waits for a final key
    answer(task.pid, "\n")

    Task.await(task)
  end

  @tag :skip
  test "unicode.z5 prover integration" do
    prover_path = Path.join(@prover_dir, "unicode.z5")
    owner = self()

    task = Task.async(fn -> Runner.run(prover_path, owner) end)

    # When the prover asks for input, send 'a'
    answer_on("Try inputing a character.", "a", task_pid: task.pid)
    # When 'a' is echoed, send '€'
    answer_on("You input 'a'", "€", task_pid: task.pid)
    # When '€' is echoed, send ESC to quit
    answer_on("You input '€'", <<27>>, task_pid: task.pid)

    expect("Unicode Test", 5000, task.pid)
    expect("Testing the Unicode table", 5000, task.pid)

    # Euro symbol check (Unicode 0x20AC)
    expect("€ © ™", 5000, task.pid)

    expect("Now, testing print_unicode()...", 5000, task.pid)

    # Runic sequence check
    expect("ᚪᛒᛇᛞᛖᚠᚷᚻᛁᛄᛣᛚᛗᚾᚩᛈᚳᚱᛋᛏᚢᛠᚹᛉᚣᛟ", 30_000, task.pid)

    expect("Now, testing input (ESC to quit)...", 5000, task.pid)
    expect("Try inputing a character.", 5000, task.pid)
    
    expect("You input 'a'", 5000, task.pid)
    expect("You input '€'", 5000, task.pid)

    expect("End of tests.", 5000, task.pid)

    Task.await(task)
  end
end
