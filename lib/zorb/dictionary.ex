defmodule Zorb.Dictionary do
  @moduledoc """
  Utilities for divining information from the Z-machine dictionary.
  """

  import Bitwise

  @doc """
  Selects the most appropriate command prefix from [/, ~, `, !] by checking
  against the story dictionary for collisions.
  """
  def select_prefix(story_binary) do
    prefixes = ["/", "~", "`", "!"]

    # Extract dictionary data once
    dict_info = extract_dictionary_info(story_binary)

    Enum.find(prefixes, fn prefix ->
      not conflicts?(prefix, dict_info)
    end) || hd(prefixes)
  end

  defp extract_dictionary_info(story_binary) do
    <<_::binary-size(8), dict_base::16, _::binary>> = story_binary
    <<_::binary-size(dict_base), num_separators::8, rest::binary>> = story_binary

    <<separators::binary-size(num_separators), entry_len::8, num_entries::16,
      vocab_entries::binary>> = rest

    %{
      separators: separators,
      entry_len: entry_len,
      num_entries: num_entries,
      vocab_entries: vocab_entries
    }
  end

  defp conflicts?(prefix, %{
         separators: separators,
         num_entries: num_entries,
         entry_len: entry_len,
         vocab_entries: vocab_entries
       }) do
    # 1. Check separators
    sep_collision? = String.contains?(separators, prefix)

    # 2. Check vocabulary entry starts
    # We'll use a simplified check for the first 16 bits of each entry.
    # Most symbols are in A2, which means the first 10 bits are [Shift to A2 (5)] + [Char Index].
    target_bits = z_encode_prefix(prefix)

    word_collision? = check_vocab_collision(vocab_entries, num_entries, entry_len, target_bits)

    sep_collision? or word_collision?
  end

  # Shift 5 (00101) + A2 index 26 (11010) = 0010111010...
  defp z_encode_prefix("/"), do: 0x1740
  # Shift 5 (00101) + A2 index 20 (10100) = 0010110100...
  defp z_encode_prefix("!"), do: 0x1680
  # Shift 5 (00101) + Escape 6 (00110) + ZSCII 126 top?
  defp z_encode_prefix("~"), do: 0x14C3
  # Actually, encoding ~ is complex. We'll use a conservative match.
  # Shift 5 + Escape 6 + ZSCII 96
  defp z_encode_prefix("`"), do: 0x14C0
  defp z_encode_prefix(_), do: 0xFFFF

  defp check_vocab_collision(_vocab_binary, 0, _entry_len, _target), do: false

  defp check_vocab_collision(vocab_binary, num_entries, entry_len, target) do
    # Check if any entry starts with the target bits (top 10 bits of the 16-bit word)
    mask = 0xFFC0
    target_prefix = target &&& mask

    Enum.any?(0..(num_entries - 1), fn i ->
      offset = i * entry_len

      case vocab_binary do
        <<_::binary-size(offset), word::16, _::binary>> ->
          (word &&& mask) == target_prefix

        _ ->
          false
      end
    end)
  end

  @doc """
  Scans the story dictionary for potential Zorbit command collisions (e.g., use of '/').
  Returns a map containing collision findings.
  """
  def collision_report(story_binary) do
    dict_info = extract_dictionary_info(story_binary)

    slash_sep? = String.contains?(dict_info.separators, "/")

    slash_word? =
      check_vocab_collision(
        dict_info.vocab_entries,
        dict_info.num_entries,
        dict_info.entry_len,
        z_encode_prefix("/")
      )

    %{
      slash_is_separator?: slash_sep?,
      slash_is_word_start?: slash_word?,
      safe_to_use_slash?: not (slash_sep? or slash_word?),
      recommended_prefix: select_prefix(story_binary)
    }
  end
end
