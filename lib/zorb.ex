defmodule Zorb do
  @moduledoc """
  Zorb is a high-performance Z-machine implementation that compiles Z-machine stories
  into optimized, standalone WebAssembly "Game Capsules".

  This module provides ergonomic entry points for compiling stories and starting
  interactive sessions.
  """

  @doc """
  Starts an interactive Z-machine session.

  The `source` can be a path to a `.z` story file or a binary containing WASM bytes.

  ## Options

    * `:notify_to` - The PID to receive output messages. Defaults to `self()`.
    * `:cache` - Whether to cache the compiled WASM capsule. Defaults to `false`.
    * `:timeout` - WASM execution timeout per step. Defaults to `:infinity`.

  ## Examples

      # From a story file
      {:ok, session} = Zorb.run("path/to/story.z5", cache: true)

      # From WASM bytes
      {:ok, session} = Zorb.run({:wasm_bytes, wasm_binary})

  """
  @spec run(binary() | {:wasm_bytes, binary()} | {:story_path, binary()}, keyword()) ::
          GenServer.on_start()
  def run(source, opts \\ []) do
    Zorb.Session.start_link(source, opts)
  end

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
  Clears all cached WASM capsules and temporary artifacts.
  """
  def clear_cache do
    Zorb.Config.clear_cache()
  end
end
