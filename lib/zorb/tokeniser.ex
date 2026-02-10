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
    st =
      case version >= 5 do
        true -> 2
        false -> 1
      end

    text_len = get_text_len(version, caller, memory, text_addr, st)
    text = Wasmex.Memory.read_binary(caller, memory, text_addr + st, text_len)

    # 3. Read dictionary
    dict_addr = if dict_addr == 0, do: read_word(caller, memory, 0x08), else: dict_addr
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

  defp read_word(caller, memory, addr) do
    <<val::16>> = Wasmex.Memory.read_binary(caller, memory, addr, 2)
    val
  end

  defp read_dictionary(caller, memory, dict_addr) do
    <<num_sep>> = Wasmex.Memory.read_binary(caller, memory, dict_addr, 1)
    separators = Wasmex.Memory.read_binary(caller, memory, dict_addr + 1, num_sep)

    dict_header_end = dict_addr + 1 + num_sep

    <<entry_len, num_entries::16-signed>> =
      Wasmex.Memory.read_binary(caller, memory, dict_header_end, 3)

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
      # require Logger
      # Logger.debug("Zorb: Tokenized '#{word}' -> 0x#{Integer.to_string(addr, 16)}")
      entry_addr = parse_addr + 2 + i * 4
      Wasmex.Memory.write_binary(caller, memory, entry_addr, <<addr::16, len::8, offset + st::8>>)
    end
  end

  defp z_encode(word, version) do
    word = String.downcase(word)
    char_map = build_char_map(version)

    {zchars, _} =
      for <<c <- word>>, reduce: {[], 0} do
        {acc, curr_alph} ->
          match_char(c, version, curr_alph, char_map, acc)
      end

    num_zchars =
      case version <= 3 do
        true -> 6
        false -> 9
      end

    zchars = Enum.take(zchars ++ [5, 5, 5, 5, 5, 5, 5, 5, 5], num_zchars)

    # Pack into 16-bit words
    words =
      for [c1, c2, c3] <- Enum.chunk_every(zchars, 3) do
        c1 <<< 10 ||| c2 <<< 5 ||| c3
      end

    # Set top bit of last word
    last_idx = length(words) - 1
    words = List.update_at(words, last_idx, &(&1 ||| 0x8000))

    res = for w <- words, into: <<>>, do: <<w::16>>
    # # require Logger
    # # Logger.debug("Zorb: Encoded '#{word}' -> #{Base.encode16(res)} (zchars: #{inspect(zchars)})")
    res
  end

  defp build_char_map(version) do
    a0 = ~c"abcdefghijklmnopqrstuvwxyz"
    a1 = ~c"ABCDEFGHIJKLMNOPQRSTUVWXYZ"

    a2 =
      case version do
        1 -> ~c" 0123456789.,!?_#'\"/\\<-:()"
        _ -> [0, 13] ++ ~c"0123456789.,!?_#'\"/\\-:()"
      end

    # Priority: A0 > A1 > A2
    map = %{}
    map = Map.put(map, 32, {0, 0})

    map =
      Enum.with_index(a2) |> Enum.reduce(map, fn {c, i}, acc -> Map.put(acc, c, {2, i + 6}) end)

    map =
      Enum.with_index(a1) |> Enum.reduce(map, fn {c, i}, acc -> Map.put(acc, c, {1, i + 6}) end)

    map =
      Enum.with_index(a0) |> Enum.reduce(map, fn {c, i}, acc -> Map.put(acc, c, {0, i + 6}) end)

    map
  end

  defp match_char(c, version, curr_alph, char_map, acc) do
    case Map.get(char_map, c) do
      {alph, idx} ->
        # Calculate shift sequence based on current and target alphabet
        shifts = get_shifts(version, curr_alph, alph)
        # Apply shifts and then the character index
        new_acc = acc ++ shifts ++ [idx]
        {new_acc, 0}

      nil ->
        # ZSCII escape
        case version >= 2 do
          true ->
            {acc ++ [5, 6, c >>> 5, c &&& 0x1F], 0}

          false ->
            # '?' for V1 unknown
            {acc ++ [63], 0}
        end
    end
  end

  defp get_shifts(version, _curr, target) do
    case {version, target} do
      {_, 0} -> []
      {_, 1} -> [4]
      {_, 2} -> [5]
      _ -> []
    end
  end

  defp find_in_dict(encoded, entries_start, num_entries, entry_len, caller, memory) do
    case num_entries < 0 do
      true ->
        # Linear search for unsorted dictionary
        num = abs(num_entries)
        linear_search(encoded, entries_start, num, entry_len, caller, memory)

      false ->
        # Binary search for sorted dictionary
        low = 0
        high = num_entries - 1
        do_find(encoded, entries_start, entry_len, caller, memory, low, high)
    end
  end

  defp linear_search(encoded, start, num, len, caller, memory) do
    word_len = byte_size(encoded)

    Enum.find_value(0..(num - 1), 0, fn i ->
      addr = start + i * len
      entry = Wasmex.Memory.read_binary(caller, memory, addr, word_len)
      if entry == encoded, do: addr, else: nil
    end)
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
    is_sep = c in seps

    case {c, is_sep} do
      {32, _} ->
        new_acc =
          case current do
            "" -> acc
            _ -> [{current, offset - byte_size(current), byte_size(current)} | acc]
          end

        do_split(rest, seps, offset + 1, new_acc, "")

      {_, true} ->
        new_acc =
          case current do
            "" -> acc
            _ -> [{current, offset - byte_size(current), byte_size(current)} | acc]
          end

        sep_word = <<c>>
        new_acc = [{sep_word, offset, 1} | new_acc]
        do_split(rest, seps, offset + 1, new_acc, "")

      {_, false} ->
        do_split(rest, seps, offset + 1, acc, current <> <<c>>)
    end
  end
end
