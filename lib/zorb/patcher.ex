defmodule Zorb.Patcher do
  @moduledoc """
  Fast compilation using WASM patching instead of full Elixir compilation.

  Pre-compiled interpreter templates are patched with story-specific data,
  reducing compilation time from ~4s to ~400ms.
  """

  alias Zorb.Patcher.Data
  alias Zorb.Templates

  @doc """
  Compile a story file using the patcher approach.

  This is ~10x faster than the traditional compilation but produces
  identical WASM output.
  """
  def compile(story_path) when is_binary(story_path) do
    story_path
    |> File.read!()
    |> compile_data()
  end

  def compile_data(story_data) when is_binary(story_data) do
    <<version::8, _::binary>> = story_data

    version
    |> Templates.get()
    |> Watusi.Patcher.patch(Data.extract(story_data))
  end
end
