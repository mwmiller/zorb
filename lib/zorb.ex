defmodule Zorb do
  @moduledoc """
  Zorb is a high-performance Z-machine implementation that compiles Z-machine stories
  into optimized, standalone WebAssembly "Game Capsules".

  This module provides the primary entry point for compiling stories into WASM.
  """

  @doc """
  Compiles a Z-machine story file into a WebAssembly Game Capsule.

  Returns the WASM binary representation of the capsule.

  ## Options

    * `:cache` - Whether to load from or save to the persistent cache. Defaults to `false`.

  ## Examples

      wasm_bytes = Zorb.compile("path/to/story.z5")
      wasm_bytes = Zorb.compile("path/to/story.z5", cache: true)

  """
  @spec compile(binary(), keyword()) :: binary()
  def compile(story_path, opts \\ []) do
    Zorb.Capsule.compile(story_path, opts)
  end

  @doc """
  Extracts metadata from a Z-machine story file.
  """
  @spec metadata(binary()) :: map()
  def metadata(story_path) do
    story_data = File.read!(story_path)
    Zorb.Inspector.analyze(story_data)
  end

  @doc """
  Clears all cached WASM capsules and temporary artifacts.
  """
  def clear_cache do
    Zorb.Config.clear_cache()
  end
end
