defmodule Zorb.Capsule do
  @moduledoc """
  The "Baking Factory" for Z-machine Game Capsules.
  """
  alias Zorb.Capsule.Assembler

  @compiler_version "0.1.0-alpha.1"

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
    key = generate_cache_key(story_data)
    dir = cache_dir()
    cache_path = Path.join(dir, "#{key}.wat")

    case File.read(cache_path) do
      {:ok, wat} ->
        wat

      {:error, :enoent} ->
        wat = perform_compile(story_data, opts)
        File.mkdir_p!(dir)
        File.write!(cache_path, wat)
        wat
    end
  end

  defp perform_compile(story_data, opts) do
    base_name = Keyword.get(opts, :name_hint, "Bespoke")
    hash = :erlang.phash2(story_data) |> Integer.to_string(16) |> String.downcase()
    module_name = Module.concat([Zorb, Capsule, "#{base_name}_#{hash}"])

    case Code.ensure_loaded?(module_name) do
      true ->
        :ok

      false ->
        IO.puts(:stderr, "Zorb: Baking bespoke module #{module_name}...")
        {source, data} = Assembler.assemble(story_data, module_name)

        binding = [
          bespoke_story_data: data.bespoke_story_data,
          bespoke_unicode_bin: data.bespoke_unicode_bin,
          bespoke_alphabets_bin: data.bespoke_alphabets_bin,
          bespoke_hash_table_bin: data.bespoke_hash_table_bin
        ]

        Code.eval_string(source, binding)
    end

    Orb.to_wat(module_name)
  end

  def generate_cache_key(story_data) do
    header =
      case story_data do
        <<h::binary-size(64), _::binary>> -> h
        h -> h
      end

    header_hash = :crypto.hash(:sha256, header) |> Base.encode16(case: :lower)
    "#{@compiler_version}-#{byte_size(story_data)}-#{String.slice(header_hash, 0, 16)}"
  end

  defp cache_dir do
    Application.get_env(:zorb, :cache_dir) ||
      Path.expand("tmp/zorb_cache")
      |> Path.join(@compiler_version)
  end
end
