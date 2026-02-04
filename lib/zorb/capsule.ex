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
    IO.puts(:stderr, "Zorb: Capsule.compile(#{story_path})")
    story_data = File.read!(story_path)

    name_hint =
      story_path
      |> Path.basename()
      |> String.split(~r/[^a-zA-Z0-9]+/)
      |> Enum.map_join(&String.capitalize/1)

    compile_data(story_data, name_hint: name_hint)
  end

  @doc """
  Compiles raw story data into WASM bytes with caching.
  """
  def compile_data(story_data, opts \\ []) when is_binary(story_data) and is_list(opts) do
    IO.puts(:stderr, "Zorb: Capsule.compile_data")
    key = generate_cache_key(story_data)
    dir = cache_dir()
    cache_path = Path.join(dir, "#{key}.wasm")

    case File.read(cache_path) do
      {:ok, wasm_bytes} ->
        IO.puts(:stderr, "Zorb: Cache HIT for #{key}")
        wasm_bytes

      {:error, :enoent} ->
        IO.puts(
          :stderr,
          "Zorb: Cache MISS for #{key}. Starting compilation of #{byte_size(story_data)} bytes..."
        )

        start_time = System.monotonic_time()

        wasm_bytes = perform_compile(story_data, opts)

        duration =
          System.convert_time_unit(System.monotonic_time() - start_time, :native, :millisecond)

        IO.puts(:stderr, "Zorb: Compilation finished in #{duration}ms")

        File.mkdir_p!(dir)
        File.write!(cache_path, wasm_bytes)
        IO.puts(:stderr, "Zorb: Successfully cached artifact to #{cache_path}")
        wasm_bytes
    end
  end

  defp perform_compile(story_data, opts) do
    base_name = Keyword.get(opts, :name_hint, "Bespoke")
    key = generate_cache_key(story_data)
    dir = cache_dir()
    cache_path = Path.join(dir, "#{key}.wasm")

    # Create a unique module name hint
    hash = :erlang.phash2(story_data) |> Integer.to_string(16) |> String.downcase()
    module_name_hint = "#{base_name}_#{hash}"

    module_name = Module.concat([Zorb, Capsule, module_name_hint])

    IO.puts(:stderr, "Zorb: Defining bespoke module #{module_name}...")

    case Code.ensure_loaded?(module_name) do
      true ->
        :ok

      false ->
        # 1. Generate the source code for the module
        IO.puts(:stderr, "Zorb: Calling Logic.generate_module_source...")
        source_code = Zorb.Interpreter.Logic.generate_module_source(module_name, story_data)
        IO.puts(:stderr, "Zorb: Logic.generate_module_source returned.")

        # 2. Compile the source code into the current VM
        IO.puts(:stderr, "Zorb: Evaluating bespoke module into VM...")

        try do
          # eval_string can also define modules
          Code.eval_string(source_code)
        rescue
          e ->
            IO.puts(:stderr, "Zorb: Evaluation CRASHED: #{inspect(e)}")
            IO.puts(:stderr, "--- FAILED SOURCE START ---")
            IO.puts(:stderr, source_code)
            IO.puts(:stderr, "--- FAILED SOURCE END ---")
            reraise e, __STACKTRACE__
        end

        IO.puts(:stderr, "Zorb: Module defined successfully.")
    end

    IO.puts(:stderr, "Zorb: Module #{module_name} loaded? #{Code.ensure_loaded?(module_name)}")

    IO.puts(:stderr, "Zorb: Generating WASM bytes from module...")
    {duration, wasm_bytes} = :timer.tc(fn -> Orb.to_wasm(module_name) end)
    IO.puts(:stderr, "Zorb: WASM generation took #{div(duration, 1000)}ms")
    IO.puts(:stderr, "Zorb: WASM generation took #{div(duration, 1000)}ms")

    File.mkdir_p!(dir)
    File.write!(cache_path, wasm_bytes)
    IO.puts(:stderr, "Zorb: Successfully cached artifact to #{cache_path}")
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
