defmodule Zorb.Templates.Generator do
  @moduledoc false
  # Helper module for generating templates at compile time

  alias Zorb.Capsule.Assembler

  def generate(version) do
    placeholder_story = create_placeholder_story(version)

    unique = :erlang.unique_integer([:positive])
    module_name = Module.concat([Zorb, Templates, "V#{version}_#{unique}"])

    {source, _data} = Assembler.assemble(placeholder_story, module_name)

    Code.compile_string(source)

    wasm =
      module_name
      |> Orb.to_wat()
      |> Watusi.to_wasm()

    :code.purge(module_name)
    :code.delete(module_name)

    wasm
  end

  defp create_placeholder_story(version) do
    <<
      version::8,
      0::8,
      0::16-big,
      0x0400::16-big,
      0x0400::16-big,
      0x0100::16-big,
      0x0200::16-big,
      0x0300::16-big,
      0x0400::16-big,
      0::16-big,
      "000000"::binary,
      0x0080::16-big,
      0x0100::16-big,
      0::16-big,
      0::16-big,
      0::32-big,
      0::32-big,
      0::32-big,
      0::16-big,
      0::16-big,
      0::16-big,
      0::16-big,
      0::16-big,
      0::16-big,
      0::16-big,
      0::16-big,
      0::64
    >> <>
      <<0, 0, 0>> <>
      String.duplicate(<<0>>, 256) <>
      String.duplicate(<<0>>, 240) <>
      <<0xB0, 0x00>>
  end
end

defmodule Zorb.Templates do
  @moduledoc """
  Pre-compiled WASM templates for each Z-machine version.
  Templates are generated at compile-time and embedded in the module.
  """
  require Logger

  @interpreter_source Path.expand("../interpreter.ex", __DIR__)
  @external_resource @interpreter_source

  @templates (for version <- [1, 2, 3, 4, 5, 7, 8], into: %{} do
                wasm = Zorb.Templates.Generator.generate(version)
                {version, wasm}
              end)

  @doc """
  Get the pre-compiled WASM template for a specific version.
  """
  def get(version) when version in [1, 2, 3, 4, 5, 7, 8] do
    Map.fetch!(@templates, version)
  end
end
