defmodule Zorb.TestSupport.Expect do
  @moduledoc """
  Helpers for expect-style testing of Z-machine stories.
  """

  import ExUnit.Assertions

  def expect(pattern, timeout \\ 5000, task_pid \\ nil) do
    do_expect("", pattern, timeout, task_pid)
  end

  def dispute(pattern) do
    disputes = Process.get(:zorb_disputes, [])
    Process.put(:zorb_disputes, [pattern | disputes])
  end

  @doc """
  Registers an answer to be sent when a pattern is matched in the output.
  Options:
    - :task_pid - The PID of the runner task (required for injection)
    - :add_newline - Whether to append a newline (default true)
  """
  def answer_on(pattern, response, opts \\ []) do
    task_pid = Keyword.get(opts, :task_pid)
    add_newline = Keyword.get(opts, :add_newline, true)

    answers = Process.get(:zorb_answers, [])
    Process.put(:zorb_answers, [{pattern, response, add_newline, task_pid} | answers])
  end

  defp do_expect(buffer, pattern, timeout, task_pid) do
    receive do
      {:zorb_output, char} ->
        # Real-time output for debugging
        IO.write(if char == ?\r, do: "\n", else: <<char::utf8>>)
        new_buffer = buffer <> List.to_string([char])

        if char == ?\r do
          check_disputes!(new_buffer)
        end

        check_answers!(new_buffer, task_pid)

        if matches?(new_buffer, pattern) do
          new_buffer
        else
          do_expect(new_buffer, pattern, timeout, task_pid)
        end

      {:zorb_halt, reason, pc, opcode} ->
        if reason == 0 do
          buffer
        else
          dump_buffer(buffer)
          flunk("Interpreter halted with reason #{reason} at PC #{pc} (opcode #{opcode}).")
        end
    after
      100 ->
        if task_pid && not Process.alive?(task_pid) do
          dump_buffer(buffer)

          flunk("Task died before pattern #{inspect(pattern)} was found.")
        end

        if timeout <= 100 do
          dump_buffer(buffer)

          flunk("Timed out waiting for pattern #{inspect(pattern)}.")
        else
          do_expect(buffer, pattern, timeout - 100, task_pid)
        end
    end
  end

  defp check_disputes!(buffer) do
    for d <- Process.get(:zorb_disputes, []) do
      maybe_flunk_dispute(buffer, d)
    end
  end

  defp maybe_flunk_dispute(buffer, d) do
    if matches?(buffer, d) do
      # Find the line that matched.
      lines = String.split(buffer, ["\r", "\n"])

      matching_line =
        Enum.find(Enum.reverse(lines), fn line -> line != "" && matches?(line, d) end) ||
          "Unknown line"

      flunk("Disputed pattern #{inspect(d)} found in line: #{String.trim(matching_line)}")
    end
  end

  defp check_answers!(buffer, default_task_pid) do
    answers = Process.get(:zorb_answers, [])

    # Use a filter map approach to avoid flunking during the loop
    remaining =
      Enum.reject(answers, fn answer ->
        should_reject?(answer, buffer, default_task_pid)
      end)

    Process.put(:zorb_answers, remaining)
  end

  defp should_reject?({pattern, response, add_newline, task_pid}, buffer, default_task_pid) do
    if matches?(buffer, pattern) do
      target_pid = task_pid || default_task_pid

      if target_pid do
        # Trigger the answer
        answer(target_pid, response, add_newline)
        # reject from remaining
        true
      else
        false
      end
    else
      false
    end
  end

  defp matches?(buffer, %Regex{} = pattern), do: Regex.run(pattern, buffer)
  defp matches?(buffer, pattern) when is_binary(pattern), do: String.contains?(buffer, pattern)

  def answer(pid, string, add_newline \\ true) do
    chars = String.to_charlist(string)

    # Z-machine often expects a newline to process input
    chars =
      if add_newline and not String.ends_with?(string, "\n") do
        chars ++ [?\n]
      else
        chars
      end

    Zorb.Runner.inject_input(pid, chars)
    # Give the Z-machine a tiny bit of time to start processing
    Process.sleep(10)
  end

  defp dump_buffer(buffer) do
    IO.puts("\n--- BUFFER DUMP START ---")
    IO.write(String.replace(buffer, "\r", "\n"))
    IO.puts("\n--- BUFFER DUMP END ---\n")
  end
end
