defmodule Zorb.Tokeniser do
  @moduledoc """
  Shared tokenization logic for the Z-machine.
  """
  import Bitwise

  def tokenize(ctx, text_addr, parse_addr, dict_addr, _flag) do
    %{caller: caller, memory: memory} = ctx

    # 1. Read version
    <<version>> = Wasmex.Memory.read_binary(caller, memory, 0, 1)

    # 2. Read text buffer
    st = if version >= 5, do: 2, else: 1
    text_len = get_text_len(version, caller, memory, text_addr, st)
    text = Wasmex.Memory.read_binary(caller, memory, text_addr + st, text_len)

    # 3. Read dictionary
    dict_info = read_dictionary(caller, memory, dict_addr)

    # 4. Split into words
    words = split_with_offsets(text, dict_info.separators)

    # 5. Write to parse buffer
    write_parse_buffer(caller, memory, parse_addr, words, version, dict_info, st)

    nil
  end

  defp get_text_len(version, caller, memory, text_addr, _st) when version >= 5 do
    <<len>> = Wasmex.Memory.read_binary(caller, memory, text_addr + 1, 1)
    len
  end

  defp get_text_len(_version, caller, memory, text_addr, st) do
    # Find null terminator
    raw = Wasmex.Memory.read_binary(caller, memory, text_addr + st, 255)

    case :binary.match(raw, <<0>>) do
      {pos, 1} -> pos
      :nomatch -> 255
    end
  end

  defp read_dictionary(caller, memory, dict_addr) do
    <<num_sep>> = Wasmex.Memory.read_binary(caller, memory, dict_addr, 1)
    separators = Wasmex.Memory.read_binary(caller, memory, dict_addr + 1, num_sep)

    dict_header_end = dict_addr + 1 + num_sep
    <<entry_len, num_entries::16>> = Wasmex.Memory.read_binary(caller, memory, dict_header_end, 3)
    entries_start = dict_header_end + 3

    %{
      separators: separators,
      entries_start: entries_start,
      entry_len: entry_len,
      num_entries: num_entries
    }
  end

  defp write_parse_buffer(
         caller,
         memory,
         parse_addr,
         words,
         version,
         dict_info,
         st
       ) do
    <<max_words>> = Wasmex.Memory.read_binary(caller, memory, parse_addr, 1)
    found_words = Enum.take(words, max_words)

    Wasmex.Memory.write_binary(caller, memory, parse_addr + 1, <<length(found_words)>>)

    for {{word, offset, len}, i} <- Enum.with_index(found_words) do
      encoded = z_encode(word, version)

      addr =
        find_in_dict(
          encoded,
          dict_info.entries_start,
          dict_info.num_entries,
          dict_info.entry_len,
          caller,
          memory
        )

      # Write to parse buffer: [dict_addr:16, word_len:8, word_offset:8]
      entry_addr = parse_addr + 2 + i * 4
      Wasmex.Memory.write_binary(caller, memory, entry_addr, <<addr::16, len::8, offset + st::8>>)
    end
  end

  defp z_encode(word, version) do
    word = String.downcase(word)
    alphabets = get_alphabets(version)

    {zchars, _} =
      for <<c <- word>>, reduce: {[], 0} do
        {acc, curr_alph} ->
          match_char(c, version, curr_alph, alphabets, acc)
      end

    num_zchars = if version <= 3, do: 6, else: 9
    zchars = Enum.take(zchars ++ [5, 5, 5, 5, 5, 5, 5, 5, 5], num_zchars)

    # Pack into 16-bit words
    words =
      for [c1, c2, c3] <- Enum.chunk_every(zchars, 3), do: c1 <<< 10 ||| c2 <<< 5 ||| c3

    # Set top bit of last word
    last_idx = length(words) - 1
    words = List.update_at(words, last_idx, &(&1 ||| 0x8000))

    for w <- words, into: <<>>, do: <<w::16>>
  end

  defp get_alphabets(_version) do
    a0 = ~c"abcdefghijklmnopqrstuvwxyz"
    a1 = ~c"ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    # A2 is same for all versions in dictionary (Spec 3.5.2)
    a2 = ~c" \r0123456789.,!?_#'\"/\\-:( )"

    {a0, a1, a2}
  end

  defp match_char(c, version, curr_alph, {a0, a1, a2}, acc) do
    cond do
      c in a0 ->
        idx = Enum.find_index(a0, &(&1 == c)) + 6
        encode_v12_v3(version, curr_alph, acc, idx, 0, [idx], [5, idx], [4, idx])

      c in a1 ->
        idx = Enum.find_index(a1, &(&1 == c)) + 6
        encode_v12_v3(version, curr_alph, acc, idx, 1, [4, idx], [idx], [5, idx])

      c in a2 ->
        idx = Enum.find_index(a2, &(&1 == c)) + 6
        z_idx = idx + 6
        encode_v12_v3(version, curr_alph, acc, z_idx, 2, [5, z_idx], [4, z_idx], [z_idx])

      true ->
        # ZSCII escape not really used in dictionary, but for completeness:
        if version >= 2 do
          {acc ++ [5, 6, c >>> 5, c &&& 0x1F], 0}
        else
          {acc ++ [63], 0}
        end
    end
  end

  defp encode_v12_v3(version, curr_alph, acc, _idx, target_alph, v12_0, v12_1, v12_2) do
    if version <= 2 do
      case curr_alph do
        0 -> {acc ++ v12_0, target_alph}
        1 -> {acc ++ v12_1, target_alph}
        2 -> {acc ++ v12_2, target_alph}
      end
    else
      # V3+ has no shift state in dictionary encoding (Spec 3.7.1)
      case target_alph do
        0 -> {acc ++ v12_0, 0}
        1 -> {acc ++ [4 | v12_1], 0}
        2 -> {acc ++ [5 | v12_2], 0}
      end
    end
  end

  defp find_in_dict(encoded, entries_start, num_entries, entry_len, caller, memory) do
    low = 0
    high = num_entries - 1
    do_find(encoded, entries_start, entry_len, caller, memory, low, high)
  end

  defp do_find(_, _, _, _, _, low, high) when low > high, do: 0

  defp do_find(encoded, start, len, caller, memory, low, high) do
    mid = div(low + high, 2)
    addr = start + mid * len
    word_len = byte_size(encoded)
    entry = Wasmex.Memory.read_binary(caller, memory, addr, word_len)

    cond do
      entry == encoded -> addr
      entry < encoded -> do_find(encoded, start, len, caller, memory, mid + 1, high)
      entry > encoded -> do_find(encoded, start, len, caller, memory, low, mid - 1)
    end
  end

  defp split_with_offsets(text, separators) do
    sep_list = for <<c <- separators>>, do: c
    do_split(text, sep_list, 0, [], "")
  end

  defp do_split(<<>>, _, _, acc, ""), do: Enum.reverse(acc)

  defp do_split(<<>>, _, offset, acc, current) do
    Enum.reverse([{current, offset - byte_size(current), byte_size(current)} | acc])
  end

  defp do_split(<<c, rest::binary>>, seps, offset, acc, current) do
    cond do
      c == 32 ->
        new_acc =
          if current == "",
            do: acc,
            else: [{current, offset - byte_size(current), byte_size(current)} | acc]

        do_split(rest, seps, offset + 1, new_acc, "")

      c in seps ->
        new_acc =
          if current == "",
            do: acc,
            else: [{current, offset - byte_size(current), byte_size(current)} | acc]

        sep_word = <<c>>
        new_acc = [{sep_word, offset, 1} | new_acc]
        do_split(rest, seps, offset + 1, new_acc, "")

      true ->
        do_split(rest, seps, offset + 1, acc, current <> <<c>>)
    end
  end
end
