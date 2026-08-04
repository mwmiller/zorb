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

  @doc """
  Prunes the cache based on size, file count, or age.
  """
  def prune_cache(opts \\ []) do
    dir = cache_dir()

    if File.exists?(dir) do
      dir
      |> list_cache_files()
      |> prune_by_age(opts[:older_than])
      |> prune_by_count(opts[:max_files])
      |> prune_by_size(opts[:max_size])
    end

    :ok
  end

  defp list_cache_files(dir) do
    dir
    |> File.ls!()
    |> Enum.filter(&String.ends_with?(&1, ".wasm"))
    |> Enum.map(fn name ->
      path = Path.join(dir, name)
      stat = File.stat!(path, time: :posix)
      %{path: path, mtime: stat.mtime, size: stat.size}
    end)
    |> Enum.sort_by(& &1.mtime, :desc)
  end

  defp prune_by_age(files, nil), do: files

  defp prune_by_age(files, seconds) do
    cutoff = System.system_time(:second) - seconds
    {keep, remove} = Enum.split_with(files, &(&1.mtime >= cutoff))
    Enum.each(remove, &File.rm!(&1.path))
    keep
  end

  defp prune_by_count(files, nil), do: files

  defp prune_by_count(files, limit) do
    {keep, remove} = Enum.split(files, limit)
    Enum.each(remove, &File.rm!(&1.path))
    keep
  end

  defp prune_by_size(_files, nil), do: :ok

  defp prune_by_size(files, limit) do
    _total =
      Enum.reduce(files, 0, fn %{path: path, size: size}, acc ->
        new_acc = acc + size

        if new_acc > limit do
          File.rm!(path)
        end

        new_acc
      end)

    :ok
  end
end
