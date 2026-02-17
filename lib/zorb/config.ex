defmodule Zorb.Config do
  @moduledoc """
  Handles configuration for Zorb, specifically directory paths for temporary artifacts and caching.
  """

  @doc """
  Returns the base working directory for Zorb artifacts.
  In a library context, this defaults to a 'zorb' directory in the system temp folder.
  """
  def working_dir do
    Application.get_env(:zorb, :working_dir) ||
      Path.join(System.tmp_dir!(), "zorb")
  end

  @doc """
  Returns the directory for cached WASM capsules.
  """
  def cache_dir do
    Application.get_env(:zorb, :cache_dir) ||
      Path.join(working_dir(), "capsule_cache")
  end

  @doc """
  Returns the path for a specific sidecar payload.
  """
  def payload_path(version) do
    Path.join(working_dir(), "payload_#{version}_#{:erlang.unique_integer([:positive])}.bin")
  end

  @doc """
  Ensures the working and cache directories exist.
  """
  def ensure_dirs! do
    File.mkdir_p!(working_dir())
    File.mkdir_p!(cache_dir())
  end

  @doc """
  Clears all cached WASM capsules and temporary artifacts.
  """
  def clear_cache do
    File.rm_rf!(working_dir())
    ensure_dirs!()
  end
end
