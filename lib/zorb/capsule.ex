defmodule Zorb.Capsule do
  @moduledoc """
  The "Baking Factory" for Z-machine Game Capsules.
  """
  alias Zorb.Capsule.Assembler

  @compiler_version Mix.Project.config()[:version]

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
    # hash = :erlang.phash2(story_data) |> Integer.to_string(16) |> String.downcase()
    unique = :erlang.unique_integer([:positive])
    module_name = Module.concat([Zorb, Capsule, "#{base_name}_#{unique}"])

    {source, _data} = Assembler.assemble(story_data, module_name)
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
end
