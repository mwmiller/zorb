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
    require Logger
    compile_start = System.monotonic_time(:millisecond)

    unique = :erlang.unique_integer([:positive])
    module_name = Module.concat([Zorb, Capsule, "#{base_name}_#{unique}"])

    assemble_start = System.monotonic_time(:millisecond)
    {source, _data} = Assembler.assemble(story_data, module_name)
    assemble_time = System.monotonic_time(:millisecond) - assemble_start
    Logger.debug("Total Assembler.assemble: #{assemble_time}ms")

    elixir_start = System.monotonic_time(:millisecond)

    try do
      Code.compile_string(source)
    rescue
      e ->
        IO.puts(:stderr, "Zorb: ERROR compiling #{module_name}: #{inspect(e)}")
        reraise e, __STACKTRACE__
    end

    elixir_time = System.monotonic_time(:millisecond) - elixir_start
    Logger.debug("Elixir Code.compile_string: #{elixir_time}ms")

    orb_start = System.monotonic_time(:millisecond)
    wat = Orb.to_wat(module_name)
    orb_time = System.monotonic_time(:millisecond) - orb_start
    Logger.debug("Orb.to_wat: #{orb_time}ms")

    watusi_start = System.monotonic_time(:millisecond)
    wasm = Watusi.to_wasm(wat)
    watusi_time = System.monotonic_time(:millisecond) - watusi_start
    Logger.debug("Watusi.to_wasm: #{watusi_time}ms")

    total_time = System.monotonic_time(:millisecond) - compile_start
    Logger.info("Total compilation: #{total_time}ms")

    File.write!(Path.join(Zorb.Config.working_dir(), "last_generated.wasm"), wasm)
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
    :crypto.hash(:sha256, [
      @compiler_version,
      Integer.to_string(byte_size(story_data)),
      story_data
    ])
    |> Base.encode16()
  end
end
