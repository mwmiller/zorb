defmodule Zorb.TestSupport.Expect do
  @moduledoc """
  Helpers for expect-style testing of Z-machine stories.
  """

  import ExUnit.Assertions

  def expect(pattern, timeout \\ 15_000, task_pid \\ nil) do
    buffer = Process.get(:zorb_expect_buffer, "")
    do_expect(buffer, pattern, timeout, task_pid)
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
    if matches?(buffer, pattern) do
      Process.put(:zorb_expect_buffer, buffer)
      buffer
    else
      wait_for_message(buffer, pattern, timeout, task_pid)
    end
  end

  defp wait_for_message(buffer, pattern, timeout, task_pid) do
    receive do
      {:zorb_output, output} ->
        handle_output(buffer, output, pattern, timeout, task_pid)

      {:zorb_halt, reason, pc, opcode} ->
        handle_halt(buffer, pattern, reason, pc, opcode)
    after
      100 ->
        handle_timeout(buffer, pattern, timeout, task_pid)
    end
  end

  defp handle_output(buffer, output, pattern, timeout, task_pid) do
    new_buffer = append_output(buffer, output)

    if is_integer(output) and output == ?\r do
      check_disputes!(new_buffer)
    end

    check_answers!(new_buffer, task_pid)
    do_expect(new_buffer, pattern, timeout, task_pid)
  end

  defp handle_halt(buffer, pattern, reason, pc, opcode) do
    if reason == 0 do
      if matches?(buffer, pattern) do
        Process.put(:zorb_expect_buffer, buffer)
        buffer
      else
        dump_buffer(buffer)
        flunk("Interpreter halted before pattern #{inspect(pattern)} was found.")
      end
    else
      dump_buffer(buffer)
      flunk("Interpreter halted with reason #{reason} at PC #{pc} (opcode #{opcode}).")
    end
  end

  defp handle_timeout(buffer, pattern, timeout, task_pid) do
    if task_pid && not Process.alive?(task_pid) do
      if matches?(buffer, pattern) do
        Process.put(:zorb_expect_buffer, buffer)
        buffer
      else
        dump_buffer(buffer)
        flunk("Task died before pattern #{inspect(pattern)} was found.")
      end
    end

    if timeout <= 100 do
      dump_buffer(buffer)
      flunk("Timed out waiting for pattern #{inspect(pattern)}.")
    else
      do_expect(buffer, pattern, timeout - 100, task_pid)
    end
  end

  defp append_output(buffer, char) when is_integer(char), do: buffer <> List.to_string([char])
  defp append_output(buffer, {:cursor, line, col}), do: buffer <> "\n[Cursor: #{line}, #{col}]\n"
  defp append_output(buffer, {:set_window, id}), do: buffer <> "\n[Set Window: #{id}]\n"
  defp append_output(buffer, {:split_window, lines}), do: buffer <> "\n[Split Window: #{lines}]\n"
  defp append_output(buffer, {:erase_window, id}), do: buffer <> "\n[Erase Window: #{id}]\n"
  defp append_output(buffer, {:erase_line, val}), do: buffer <> "[Erase Line: #{val}]"
  defp append_output(buffer, {:style, style}), do: buffer <> "[Style: #{style}]"
  defp append_output(buffer, {:colour, fg, bg}), do: buffer <> "[Colour: #{fg}, #{bg}]"
  defp append_output(buffer, {:sound, number}), do: buffer <> "[Sound: #{number}]"
  defp append_output(buffer, other), do: buffer <> "[Unknown Output: #{inspect(other)}]"

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

    for char <- chars, do: Zorb.Session.send_input(pid, char)
    # Give the Z-machine a tiny bit of time to start processing
    Process.sleep(10)
  end

  def dump_buffer(buffer) do
    IO.puts("\n--- BUFFER DUMP START ---")
    IO.write(String.replace(buffer, "\r", "\n"))
    IO.puts("\n--- BUFFER DUMP END ---\n")
  end
end
