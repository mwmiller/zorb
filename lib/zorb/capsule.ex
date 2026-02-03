defmodule Zorb.Capsule do
  @moduledoc """
  The "Baking Factory" for Z-machine Game Capsules.

  This module provides the ergonomics for transforming raw Z-machine story files 
  into optimized, standalone WASM binaries with a persistent caching layer.
  """

  # Increment this version whenever the interpreter logic or memory layout changes.
  # This ensures that cached artifacts are invalidated when the compiler is updated.
  @compiler_version "0.1.0-alpha.1"

  @doc """
  Returns the current version of the Zorb capsule compiler.
  """
  def compiler_version, do: @compiler_version

  @doc """
  Compiles a story file into WASM bytes, using the persistent cache if possible.
  """
  def compile(story_path) when is_binary(story_path) do
    story_data = File.read!(story_path)
    compile_data(story_data)
  end

  @doc """
  Compiles raw story data into WASM bytes with caching.
  """
  def compile_data(story_data) when is_binary(story_data) do
    key = generate_cache_key(story_data)
    dir = cache_dir()
    cache_path = Path.join(dir, "#{key}.wasm")

    case File.read(cache_path) do
      {:ok, wasm_bytes} ->
        IO.puts("Zorb: Cache HIT for #{key}")
        wasm_bytes

      {:error, :enoent} ->
        IO.puts(
          "Zorb: Cache MISS for #{key}. Starting compilation of #{byte_size(story_data)} bytes..."
        )

        start_time = System.monotonic_time()

        wasm_bytes = perform_compile(story_data)

        duration =
          System.convert_time_unit(System.monotonic_time() - start_time, :native, :millisecond)

        IO.puts("Zorb: Compilation finished in #{duration}ms")

        File.mkdir_p!(dir)
        File.write!(cache_path, wasm_bytes)
        IO.puts("Zorb: Successfully cached artifact to #{cache_path}")
        wasm_bytes
    end
  end

  defp perform_compile(story_data) do
    hash = :erlang.phash2(story_data)
    module_name = Module.concat(Zorb.Capsule, "Generated#{hash}")

    IO.puts("Zorb: Defining bespoke module #{module_name}...")

    unless Code.ensure_loaded?(module_name) do
      contents =
        quote do
          defmodule unquote(module_name) do
            use Orb
            Orb.Memory.pages(16)
            use Zorb.Interpreter.Logic, story_data: unquote(story_data)
          end
        end

      {duration, _result} = :timer.tc(fn -> Code.eval_quoted(contents) end)
      IO.puts("Zorb: Module definition (macro expansion) took #{div(duration, 1000)}ms")
    end

    IO.puts("Zorb: Generating WASM bytes from module...")
    {duration, wasm_bytes} = :timer.tc(fn -> Orb.to_wasm(module_name) end)
    IO.puts("Zorb: WASM generation took #{div(duration, 1000)}ms")

    wasm_bytes
  end

  @doc """
  Generates a unique cache key based on compiler version and story header.
  """
  def generate_cache_key(story_data) do
    header = :binary.part(story_data, 0, min(byte_size(story_data), 64))
    header_hash = :crypto.hash(:sha256, header) |> Base.encode16(case: :lower)
    size = byte_size(story_data)

    # Key format: <v>-<size>-<header_hash_prefix>
    "#{@compiler_version}-#{size}-#{String.slice(header_hash, 0, 16)}"
  end

  defp cache_dir do
    # Default to a tmp directory in the current working directory, 
    # but allow override via config.
    base = Application.get_env(:zorb, :cache_dir) || Path.expand("tmp/zorb_cache")
    Path.join(base, @compiler_version)
  end

  @doc """
  Compiles a story file and writes the resulting WASM to a file.
  """
  def compile_to_file(story_path, output_wasm_path) do
    wasm_bytes = compile(story_path)
    File.write!(output_wasm_path, wasm_bytes)
  end
end
