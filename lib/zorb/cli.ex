defmodule Zorb.CLI do
  @moduledoc """
  Command-line interface for Zorb.
  """

  def main(args) do
    # Ensure dependencies are started if running as escript
    Application.ensure_all_started(:wasmex)
    Application.ensure_all_started(:logger)

    case args do
      [path] ->
        if File.exists?(path) do
          run(path)
        else
          IO.puts("Error: File not found: #{path}")
          System.halt(1)
        end

      _ ->
        IO.puts("Usage: zorb path/to/story.z[1-8]")
        System.halt(1)
    end
  end

  def run(path) do
    parent = self()
    # We use cache: true by default for CLI usage to speed up subsequent runs
    {:ok, session_pid} = Zorb.Session.start_link(path, notify_to: parent, cache: true)

    # Bridge stdin to the session
    spawn_link(fn -> bridge_stdin(session_pid) end)

    loop(session_pid)
  end

  defp bridge_stdin(session_pid) do
    Stream.resource(
      fn -> :ok end,
      fn _ ->
        case IO.getn("", 1) do
          :eof -> {:halt, :ok}
          {:error, _} -> {:halt, :ok}
          char -> {[char], :ok}
        end
      end,
      fn _ -> :ok end
    )
    |> Enum.each(fn char ->
      Zorb.Session.send_input(session_pid, char)
    end)
  end

  defp loop(session_pid) do
    receive do
      {:zorb_output, char} when is_integer(char) ->
        case char do
          13 -> IO.write("\n")
          c -> IO.write([c])
        end

        loop(session_pid)

      {:zorb_output, _other} ->
        # Handle or ignore other output types (cursor, style, etc.)
        loop(session_pid)

      {:zorb_halt, reason, pc, _opcode} ->
        if reason != 0 do
          IO.puts("\n\nHalted with reason #{reason} at PC #{pc}")
          System.halt(1)
        end

        :ok

      _ ->
        loop(session_pid)
    end
  end
end
