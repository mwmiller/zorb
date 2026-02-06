defmodule Zorb.Capsule do
  @moduledoc """
  The "Baking Factory" for Z-machine Game Capsules.
  """
  alias Zorb.Capsule.Assembler

  @compiler_version "0.1.0-alpha.1"
  @compiler_files [
    "lib/zorb/interpreter.ex",
    "lib/zorb/capsule/assembler.ex",
    "lib/zorb/interpreter/types.ex",
    "lib/zorb/capsule/host.ex"
  ]

  def compiler_version, do: @compiler_version

  def compile(story_path) when is_binary(story_path) do
    story_data = File.read!(story_path)

    name_hint =
      story_path
      |> Path.basename()
      |> String.split(~r/[^a-zA-Z0-9]+/)
      |> Enum.map_join(&String.capitalize/1)

    compile_data(story_data, name_hint: name_hint)
  end

  def compile_data(story_data, opts \\ []) when is_binary(story_data) and is_list(opts) do
    perform_compile(story_data, opts)
  end

  defp perform_compile(story_data, opts) do
    base_name = Keyword.get(opts, :name_hint, "Bespoke")
    hash = :erlang.phash2(story_data) |> Integer.to_string(16) |> String.downcase()
    module_name = Module.concat([Zorb, Capsule, "#{base_name}_#{hash}"])

    key = generate_cache_key(story_data)
    ex_path = Path.join(cache_dir(), "#{key}.ex")

    case Code.ensure_loaded?(module_name) do
      true ->
        :ok

      false ->
        {source, _data} = Assembler.assemble(story_data, module_name)
        File.mkdir_p!(cache_dir())
        File.write!(ex_path, source)

        try do
          Code.compile_string(source)
        catch
          kind, e ->
            IO.puts(:stderr, "Zorb: ERROR compiling #{module_name}: #{kind} #{inspect(e)}")
            reraise e, __STACKTRACE__
        end
    end

    wat = Orb.to_wat(module_name)
    File.write!("tmp/last_generated.wat", wat)
    wat
  end

  def generate_cache_key(story_data) do
    header =
      case story_data do
        <<h::binary-size(64), _::binary>> -> h
        h -> h
      end

    compiler_hash =
      @compiler_files
      |> Enum.map(&File.read!/1)
      |> Enum.join()
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode16(case: :lower)
      |> String.slice(0, 8)

    header_hash = :crypto.hash(:sha256, header) |> Base.encode16(case: :lower)

    "#{@compiler_version}-#{compiler_hash}-#{byte_size(story_data)}-#{String.slice(header_hash, 0, 8)}"
  end

  defp cache_dir do
    Application.get_env(:zorb, :cache_dir) ||
      Path.expand("tmp/zorb_cache")
      |> Path.join(@compiler_version)
  end
end
