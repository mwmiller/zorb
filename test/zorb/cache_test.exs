defmodule Zorb.CacheTest do
  use ExUnit.Case
  alias Zorb.Config

  @story_path "test/fixtures/provers/simple_test.z5"

  setup do
    Zorb.clear_cache()
    :ok
  end

  test "cache hash is stable" do
    wasm1 = Zorb.compile(@story_path, cache: true)

    dir = Config.cache_dir()
    files = File.ls!(dir)
    assert Enum.count(files) == 1

    wasm2 = Zorb.compile(@story_path, cache: true)
    assert wasm1 == wasm2
    assert Enum.count(File.ls!(dir)) == 1
  end

  test "prune_cache with max_files" do
    dir = Config.cache_dir()
    File.mkdir_p!(dir)

    f1 = Path.join(dir, "oldest.wasm")
    f2 = Path.join(dir, "middle.wasm")
    f3 = Path.join(dir, "newest.wasm")

    File.write!(f1, "oldest")
    File.touch!(f1, {{2020, 1, 1}, {0, 0, 0}})

    File.write!(f2, "middle")
    File.touch!(f2, {{2021, 1, 1}, {0, 0, 0}})

    File.write!(f3, "newest")
    File.touch!(f3, {{2022, 1, 1}, {0, 0, 0}})

    assert Enum.count(File.ls!(dir)) == 3

    Zorb.prune_cache(max_files: 2)

    remaining = File.ls!(dir)
    assert Enum.count(remaining) == 2
    refute "oldest.wasm" in remaining
    assert "middle.wasm" in remaining
    assert "newest.wasm" in remaining
  end

  test "prune_cache with max_size" do
    dir = Config.cache_dir()
    File.mkdir_p!(dir)

    f1 = Path.join(dir, "a.wasm")
    f2 = Path.join(dir, "b.wasm")
    f3 = Path.join(dir, "c.wasm")

    File.write!(f1, String.duplicate("a", 10))
    File.touch!(f1, {{2020, 1, 1}, {0, 0, 0}})

    File.write!(f2, String.duplicate("b", 10))
    File.touch!(f2, {{2021, 1, 1}, {0, 0, 0}})

    File.write!(f3, String.duplicate("c", 10))
    File.touch!(f3, {{2022, 1, 1}, {0, 0, 0}})

    Zorb.prune_cache(max_size: 25)

    remaining = File.ls!(dir)
    assert Enum.count(remaining) == 2
    refute "a.wasm" in remaining
  end

  test "load_from_cache updates mtime (LRU)" do
    _wasm = Zorb.compile(@story_path, cache: true)
    dir = Config.cache_dir()
    [file] = File.ls!(dir)
    path = Path.join(dir, file)

    old_time = {{2020, 1, 1}, {0, 0, 0}}
    File.touch!(path, old_time)

    assert File.stat!(path).mtime == old_time

    # Trigger cache hit
    Zorb.compile(@story_path, cache: true)

    # Check that mtime is updated to something newer
    assert File.stat!(path).mtime != old_time
  end
end
