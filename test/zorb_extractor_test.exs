defmodule Zorb.ExtractorTest.Conflicts do
  use ExUnit.Case, async: true
  alias Zorb.Extractor

  test "collision_audit/1 chooses / when no collision" do
    # Minimal valid story with a dictionary that doesn't contain /
    story = build_minimal_story([])
    assert Extractor.collision_audit(story).recommended_prefix == "/"
  end

  test "collision_audit/1 chooses ~ when / conflicts" do
    # Dictionary where / is a separator
    story = build_minimal_story([?/])
    assert Extractor.collision_audit(story).recommended_prefix == "~"
  end

  test "collision_audit/1 chooses ! when /, ~, and ` conflict" do
    story = build_minimal_story([?/, ?~, ?`])
    assert Extractor.collision_audit(story).recommended_prefix == "!"
  end

  test "collision_audit/1 returns nil when all prefixes conflict" do
    story = build_minimal_story([?/, ?~, ?`, ?!])
    assert Extractor.collision_audit(story).recommended_prefix == nil
  end

  defp build_minimal_story(separators) do
    # Version 3 at offset 0
    # Header: 64 bytes. Offset 8 is dict_base.
    dict_base = 64
    header = <<3>> <> :binary.copy(<<0>>, 63)
    header = put_word(header, 8, dict_base)

    num_seps = length(separators)
    sep_binary = :binary.list_to_bin(separators)

    # Dict: num_seps, seps, entry_len (7), num_entries (0)
    dict = <<num_seps::8, sep_binary::binary, 7::8, 0::16>>

    header <> dict
  end

  defp put_word(bin, offset, value) do
    prefix = binary_part(bin, 0, offset)
    suffix = binary_part(bin, offset + 2, byte_size(bin) - offset - 2)
    prefix <> <<value::16>> <> suffix
  end
end
