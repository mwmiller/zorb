defmodule Zorb.Capsule do
  @moduledoc """
  The "Baking Factory" for Z-machine Game Capsules.
  """
  alias Zorb.Capsule.Assembler

  @compiler_version Mix.Project.config()[:version]
  @cache_dir "tmp/capsule_cache"

  def compiler_version, do: @compiler_version

  @doc """
  Compiles a story file into a WASM capsule.
  Options:
  - `:cache`: Boolean, whether to cache the result. Defaults to `false`.
  """
  def compile(story_path, opts \\ []) when is_binary(story_path) do
    story_data = File.read!(story_path)

    if Keyword.get(opts, :cache, false) do
      case load_from_cache(story_data) do
        {:ok, wasm} ->
          wasm

        :error ->
          wasm = compile_data(story_data, opts)
          save_to_cache(story_data, wasm)
          wasm
      end
    else
      compile_data(story_data, opts)
    end
  end

  def compile_data(story_data, opts \\ []) when is_binary(story_data) and is_list(opts) do
    name_hint = Keyword.get(opts, :name_hint, "Bespoke")
    perform_compile(story_data, name_hint)
  end

  defp perform_compile(story_data, base_name) do
    unique = :erlang.unique_integer([:positive])
    module_name = Module.concat([Zorb, Capsule, "#{base_name}_#{unique}"])

    {source, _data} = Assembler.assemble(story_data, module_name)
    File.mkdir_p!("tmp")
    File.write!("tmp/last_assembled.ex", source)

    try do
      Code.compile_string(source)
    catch
      kind, e ->
        IO.puts(:stderr, "Zorb: ERROR compiling #{module_name}: #{kind} #{inspect(e)}")
        reraise e, __STACKTRACE__
    end

    wat = Orb.to_wat(module_name)
    File.write!("tmp/last_generated.wat", wat)
    wat
  end

  defp load_from_cache(story_data) do
    hash = :crypto.hash(:sha256, story_data) |> Base.encode16()
    path = Path.join(@cache_dir, "#{hash}.wat")

    if File.exists?(path) do
      {:ok, File.read!(path)}
    else
      :error
    end
  end

  defp save_to_cache(story_data, wasm) do
    hash = :crypto.hash(:sha256, story_data) |> Base.encode16()
    File.mkdir_p!(@cache_dir)
    File.write!(Path.join(@cache_dir, "#{hash}.wat"), wasm)
  end
end
