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

  test "zil_test.z3 prover integration" do
    prover_path = Path.join(@prover_dir, "zil_test.z3")
    owner = self()

    task = Task.async(fn -> Runner.run(prover_path, owner) end)

    expect("A TEST FILE", 5000, task.pid)
    expect("TESTING LAB", 5000, task.pid)
    answer(task.pid, "quit\n")
    expect("Are you sure you want to quit?", 5000, task.pid)
    answer(task.pid, "y\n")

    Task.await(task, 60_000)
  end

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

    Task.await(task, 60_000)
  end

  test "strictz.z5 prover integration" do
    prover_path = Path.join(@prover_dir, "strictz.z5")
    owner = self()

    task = Task.async(fn -> Runner.run(prover_path, owner) end)

    dispute("incorrect")

    expect("Strict Z Test", 5000, task.pid)
    # StrictZ asks about transcript. It uses read_char.
    # We wait for the prompt then send 'N'
    expect("(Y/N)", 5000, task.pid)
    answer(task.pid, "N")

    expect("Test completed!", 60_000, task.pid)

    # Prover waits for a final key
    answer(task.pid, "\n")

    Task.await(task, 60_000)
  end

  test "simple_test.z5 prover integration" do
    prover_path = Path.join(@prover_dir, "simple_test.z5")
    owner = self()

    task = Task.async(fn -> Runner.run(prover_path, owner) end)

    expect("units 0 by 0", 5000, task.pid)
    answer(task.pid, "quit\n")

    Task.await(task, 60_000)
  end

  test "unicode.z5 prover integration" do
    prover_path = Path.join(@prover_dir, "unicode.z5")
    owner = self()

    task = Task.async(fn -> Runner.run(prover_path, owner) end)

    # When the prover asks for input, send '€'
    answer_on("Try inputing a character.", "€", task_pid: task.pid)
    # When '€' is processed, send ESC to quit
    # In the custom Unicode table provided by unicode.z5, Euro is at ZSCII 0xE2.
    answer_on("ZSCII $00e2 = €", <<27>>, task_pid: task.pid, add_newline: false)

    expect("Unicode Test", 5000, task.pid)

    expect(
      "Testing the Unicode table. This sentence should end with Euro, copyright and trademark symbols € © ™",
      5000,
      task.pid
    )

    # Euro symbol check (Unicode 0x20AC)
    expect("Now, testing print_unicode()...", 5000, task.pid)
    expect("Basic Latin", 10_000, task.pid)
    expect("0020 :  !\"\#$%&'()*+,-./0123456789:;<=>?", 5000, task.pid)
    expect("Latin-1 Supplement", 10_000, task.pid)
    expect("00a0 :  ¡¢£¤¥¦§¨©ª«¬­®¯°±²³´µ¶·¸¹º»¼½¾¿", 5000, task.pid)
    expect("Arabic", 20_000, task.pid)

    expect("Now, testing input (ESC to quit)...", 5000, task.pid)
    expect("ZSCII $00e2 = €", 5000, task.pid)

    Task.await(task, 60_000)
  end

  test "zork1.z1 integration" do
    prover_path = Path.join(@prover_dir, "zork1.z1")
    owner = self()

    task = Task.async(fn -> Runner.run(prover_path, owner) end)

    expect("ZORK: The Great Underground Empire - Part I", 5000, task.pid)
    expect("West of House", 5000, task.pid)
    answer(task.pid, "quit\n")
    expect("leave the game", 5000, task.pid)
    answer(task.pid, "y\n")

    Task.await(task, 60_000)
  end

  test "zork1.z2 integration" do
    prover_path = Path.join(@prover_dir, "zork1.z2")
    owner = self()

    task = Task.async(fn -> Runner.run(prover_path, owner) end)

    expect("ZORK: The Great Underground Empire - Part I", 5000, task.pid)
    expect("West of House", 5000, task.pid)
    answer(task.pid, "quit\n")
    expect("leave the game", 5000, task.pid)
    answer(task.pid, "y\n")

    Task.await(task, 60_000)
  end

  test "simple_test.z7 integration" do
    prover_path = Path.join(@prover_dir, "simple_test.z7")
    owner = self()

    task = Task.async(fn -> Runner.run(prover_path, owner) end)

    expect("units 0 by 0", 5000, task.pid)
    answer(task.pid, "quit\n")

    Task.await(task, 60_000)
  end
end
