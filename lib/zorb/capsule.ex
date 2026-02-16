defmodule Zorb.Capsule do
  @moduledoc """
  The "Baking Factory" for Z-machine Game Capsules.
  """
  alias Zorb.Capsule.Assembler

  @compiler_version Mix.Project.config()[:version]

  @doc """
  Returns the compiler version of the Zorb Baking Factory.
  """
  def compiler_version, do: @compiler_version

  @doc """
  Compiles a story file into a WASM capsule.

  ## Options
    * `:cache` - Boolean, whether to cache the result. Defaults to `false`.
  """
  def compile(story_path, opts \\ []) when is_binary(story_path) do
    story_data = File.read!(story_path)

    if Keyword.get(opts, :cache, false) do
      case load_from_cache(story_data) do
        {:ok, wasm} ->
          wasm

        :error ->
          wasm = perform_compile(story_data, "Bespoke")
          save_to_cache(story_data, wasm)
          wasm
      end
    else
      perform_compile(story_data, "Bespoke")
    end
  end

  defp perform_compile(story_data, base_name) do
    unique = :erlang.unique_integer([:positive])
    module_name = Module.concat([Zorb, Capsule, "#{base_name}_#{unique}"])

    {source, _data} = Assembler.assemble(story_data, module_name)
    Zorb.Config.ensure_dirs!()
    File.write!(Path.join(Zorb.Config.working_dir(), "last_assembled.ex"), source)

    try do
      Code.compile_string(source)
    catch
      kind, e ->
        IO.puts(:stderr, "Zorb: ERROR compiling #{module_name}: #{kind} #{inspect(e)}")
        reraise e, __STACKTRACE__
    end

    wasm =
      module_name
      |> Orb.to_wat()
      |> Watusi.to_wasm()

    File.write!(Path.join(Zorb.Config.working_dir(), "last_generated.wasm"), wasm)
    wasm
  end

  defp load_from_cache(story_data) do
    hash = :crypto.hash(:sha256, story_data) |> Base.encode16()
    path = Path.join(Zorb.Config.cache_dir(), "#{hash}.wasm")

    if File.exists?(path) do
      {:ok, File.read!(path)}
    else
      :error
    end
  end

  defp save_to_cache(story_data, wasm) do
    hash = :crypto.hash(:sha256, story_data) |> Base.encode16()
    File.mkdir_p!(Zorb.Config.cache_dir())
    File.write!(Path.join(Zorb.Config.cache_dir(), "#{hash}.wasm"), wasm)
  end
end
