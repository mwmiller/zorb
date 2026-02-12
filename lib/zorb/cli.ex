defmodule Zorb.CLI do
  @moduledoc false

  @version Mix.Project.config()[:version]

  def main(args) do
    # Ensure dependencies are started if running as escript
    Application.load(:wasmex)
    Application.ensure_all_started(:wasmex)
    Application.ensure_all_started(:logger)

    {opts, args, _invalid} =
      OptionParser.parse(args,
        switches: [help: :boolean, version: :boolean, cache: :boolean],
        aliases: [h: :help, v: :version, c: :cache]
      )

    cond do
      opts[:help] ->
        print_help()

      opts[:version] ->
        IO.puts("Zorb v#{@version}")

      args == [] ->
        print_help()

      true ->
        [path | _] = args

        if File.exists?(path) do
          run(path, opts)
        else
          IO.puts("Error: File not found: #{path}")
          System.halt(1)
        end
    end
  end

  defp print_help do
    IO.puts("""
    Zorb v#{@version} - High-performance Z-machine Game Capsules

    Usage:
      zorb path/to/story.z[1-8] [options]

    Options:
      -h, --help     Show this help
      -v, --version  Show version
      -c, --cache    Enable compilation cache (recommended)

    Example:
      zorb zork1.z3 --cache
    """)
  end

  def run(path, opts \\ []) do
    parent = self()
    # We use cache: true by default for CLI usage if requested
    {:ok, session_pid} =
      Zorb.Session.start_link(path, notify_to: parent, cache: Keyword.get(opts, :cache, false))

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
