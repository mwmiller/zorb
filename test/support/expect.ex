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

  defp do_expect(buffer, pattern, timeout, task_pid) do
    receive do
      {:zorb_output, char} ->
        # Real-time output for debugging
        IO.write(if char == ?\r, do: "\n", else: <<char>>)
        new_buffer = buffer <> List.to_string([char])

        if char == ?\r do
          check_disputes!(new_buffer)
        end

        if matches?(new_buffer, pattern) do
          new_buffer
        else
          do_expect(new_buffer, pattern, timeout, task_pid)
        end

      {:zorb_halt, reason, pc, opcode} ->
        dump_buffer(buffer)

        flunk("Interpreter halted with reason #{reason} at PC #{pc} (opcode #{opcode}).")
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
      if matches?(buffer, d) do
        # Find the line that matched.
        lines = String.split(buffer, ["\r", "\n"])

        matching_line =
          Enum.find(Enum.reverse(lines), fn line -> line != "" && matches?(line, d) end) ||
            "Unknown line"

        flunk("Disputed pattern #{inspect(d)} found in line: #{String.trim(matching_line)}")
      end
    end
  end

  defp dump_buffer(buffer) do
    IO.puts("\n--- BUFFER DUMP START ---")
    IO.puts(String.replace(buffer, "\r", "\n"))
    IO.puts("--- BUFFER DUMP END ---\n")
  end

  defp matches?(buffer, %Regex{} = pattern), do: Regex.run(pattern, buffer)
  defp matches?(buffer, pattern) when is_binary(pattern), do: String.contains?(buffer, pattern)

  def answer(pid, string) do
    chars = String.to_charlist(string)

    # Z-machine often expects a newline to process input
    chars =
      if String.ends_with?(string, "\n") do
        chars
      else
        chars ++ [?\n]
      end

    Zorb.Runner.inject_input(pid, chars)
    # Give the Z-machine a tiny bit of time to start processing
    Process.sleep(10)
  end
end
