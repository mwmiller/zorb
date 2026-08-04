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
    * `:method` - Compilation method: `:patcher` (fast, default) or `:traditional` (slow, for debugging)
  """
  def compile(story_path, opts \\ []) when is_binary(story_path) do
    story_data = File.read!(story_path)

    <<version::8, _::binary>> = story_data

    if version == 6 do
      raise ArgumentError,
            "Zorb does not support Z-machine version 6 (graphical). Supported versions: 1-5, 7, 8."
    end

    if version not in [1, 2, 3, 4, 5, 7, 8] do
      raise ArgumentError,
            "Unsupported Z-machine version: #{version}. Supported versions: 1-5, 7, 8."
    end

    if Keyword.get(opts, :cache, false) do
      case load_from_cache(story_data) do
        {:ok, wasm} ->
          wasm

        :error ->
          wasm = perform_compile(story_data, opts)
          save_to_cache(story_data, wasm)
          wasm
      end
    else
      perform_compile(story_data, opts)
    end
  end

  defp perform_compile(story_data, opts) do
    method = Keyword.get(opts, :method, :patcher)

    case method do
      :patcher ->
        Zorb.Patcher.compile_data(story_data)

      :traditional ->
        perform_traditional_compile(story_data, "Bespoke")
    end
  end

  defp perform_traditional_compile(story_data, base_name) do
    unique = :erlang.unique_integer([:positive])
    module_name = Module.concat([Zorb, Capsule, "#{base_name}_#{unique}"])

    {source, payload_path} = Assembler.assemble(story_data, module_name)

    try do
      Code.compile_string(source)
    rescue
      e ->
        IO.puts(:stderr, "Zorb: ERROR compiling #{module_name}: #{inspect(e)}")
        reraise e, __STACKTRACE__
    end

    wasm =
      module_name
      |> Orb.to_wat()
      |> Watusi.to_wasm()

    File.write!(Path.join(Zorb.Config.working_dir(), "last_generated.wasm"), wasm)

    if is_binary(payload_path) do
      File.rm!(payload_path)
    end

    wasm
  end

  defp load_from_cache(story_data) do
    hash = cache_hash(story_data)
    path = Path.join(Zorb.Config.cache_dir(), "#{hash}.wasm")

    if File.exists?(path) do
      File.touch!(path)
      {:ok, File.read!(path)}
    else
      :error
    end
  end

  defp save_to_cache(story_data, wasm) do
    hash = cache_hash(story_data)
    File.mkdir_p!(Zorb.Config.cache_dir())
    File.write!(Path.join(Zorb.Config.cache_dir(), "#{hash}.wasm"), wasm)
  end

  defp cache_hash(story_data) do
    watusi_version = Application.spec(:watusi, :vsn) || "unknown"
    orb_version = Application.spec(:orb, :vsn) || "unknown"

    :crypto.hash(:sha256, [
      @compiler_version,
      watusi_version,
      orb_version,
      Integer.to_string(byte_size(story_data)),
      story_data
    ])
    |> Base.encode16()
  end
end
