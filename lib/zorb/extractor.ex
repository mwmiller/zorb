defmodule Zorb.Extractor do
  @moduledoc "Static analysis tool."
  import Bitwise

  def extract(path) do
    data = File.read!(path)
    version = :binary.at(data, 0)

    words = dictionary(data)

    IO.puts("--- Dictionary (V#{version}) ---")
    Enum.each(words, &IO.puts/1)

    # Simple heuristic scan for strings in high memory
    static_base = :binary.at(data, 14) <<< 8 ||| :binary.at(data, 15)
    IO.puts("\n--- Strings from 0x#{Integer.to_string(static_base, 16)} ---")
    scan_strings(data, static_base, version)
  end

  def dictionary(data) do
    version = :binary.at(data, 0)
    dict_addr = :binary.at(data, 8) <<< 8 ||| :binary.at(data, 9)
    extract_dictionary(data, dict_addr, version)
  end

  def collision_audit(data, reserved_commands \\ ["chat", "who", "me", "quit"]) do
    words = dictionary(data)
    prefixes = ["/", "~", "`", "!"]

    # 1. Check for exact word collisions with reserved commands
    collisions = Enum.filter(words, &(&1 in reserved_commands))

    # 2. Check for prefix collisions
    dict_addr = :binary.at(data, 8) <<< 8 ||| :binary.at(data, 9)
    num_separators = :binary.at(data, dict_addr)
    separators = :binary.part(data, dict_addr + 1, num_separators) |> String.to_charlist()

    safe_prefix =
      Enum.find(prefixes, fn prefix ->
        p_char = hd(String.to_charlist(prefix))
        not (p_char in separators or Enum.any?(words, &String.starts_with?(&1, prefix)))
      end)

    %{
      word_collisions: collisions,
      recommended_prefix: safe_prefix
    }
  end

  defp extract_dictionary(data, addr, version) do
    num_separators = :binary.at(data, addr)
    header_end = addr + 1 + num_separators
    entry_len = :binary.at(data, header_end)
    num_entries = :binary.at(data, header_end + 1) <<< 8 ||| :binary.at(data, header_end + 2)
    entries_start = header_end + 3

    case num_entries do
      0 ->
        []

      n ->
        for i <- 0..(n - 1) do
          entry_addr = entries_start + i * entry_len
          encoded = :binary.part(data, entry_addr, if(version <= 3, do: 4, else: 6))
          decode_zstring(encoded, version)
        end
    end
  end

  def decode_zstring(binary, version, data \\ nil) do
    zchars = for <<w::16-big <- binary>>, do: [w >>> 10 &&& 31, w >>> 5 &&& 31, w &&& 31]
    zchars = List.flatten(zchars)

    a0 = ~c"abcdefghijklmnopqrstuvwxyz"
    a1 = ~c"ABCDEFGHIJKLMNOPQRSTUVWXYZ"

    a2 =
      case version do
        1 -> ~c" 0123456789.,!?_#'\"/\\<-:()"
        2 -> ~c" \r0123456789.,!?_#'\"/\\-:()"
        _ -> ~c" 0123456789.,!?_#'\"/\\-:() "
      end

    alphabets = [a0, a1, a2]

    abbrev_base =
      case data do
        nil -> 0
        _ -> :binary.at(data, 0x18) <<< 8 ||| :binary.at(data, 0x19)
      end

    {text, _, _, _} =
      Enum.reduce(zchars, {[], 0, -1, 0}, fn z, {acc, curr, next, abbrev_bank} ->
        effective =
          case next do
            -1 -> curr
            _ -> next
          end

        cond do
          abbrev_bank > 0 ->
            case {data, abbrev_base} do
              {nil, _} ->
                {acc ++ ~c"[ABBR]", curr, -1, 0}

              {_, 0} ->
                {acc ++ ~c"[ABBR]", curr, -1, 0}

              {_, _} ->
                # Abbrev address is a word address, so multiply by 2
                entry_addr = abbrev_base + ((abbrev_bank - 1) * 32 + z) * 2

                word_addr =
                  :binary.at(data, entry_addr) <<< 8 ||| :binary.at(data, entry_addr + 1)

                # Abbreviations are word addresses (Spec 1.2.2)
                ptr = word_addr * 2

                # Simple recursive decode (avoid cycles for now)
                {words, _} = collect_zwords(data, ptr)
                expanded = decode_zstring_list(words, version, data)
                {acc ++ String.to_charlist(expanded), curr, -1, 0}
            end

          z == 0 ->
            {acc ++ [?\s], curr, -1, 0}

          z == 1 and version == 1 ->
            {acc ++ [?\n], curr, -1, 0}

          z in [1, 2, 3] and version >= 2 ->
            {acc, curr, -1, z}

          z == 2 and version <= 2 ->
            {acc, curr, 1, 0}

          z == 3 and version <= 2 ->
            {acc, curr, 2, 0}

          z == 4 and version <= 2 ->
            {acc, 1, -1, 0}

          z == 5 and version <= 2 ->
            {acc, 2, -1, 0}

          z == 4 and version >= 3 ->
            {acc, curr, 1, 0}

          z == 5 and version >= 3 ->
            {acc, curr, 2, 0}

          z >= 6 ->
            char = Enum.at(alphabets, effective) |> Enum.at(z - 6)
            {acc ++ [char], curr, -1, 0}

          true ->
            {acc, curr, next, 0}
        end
      end)

    List.to_string(text)
  end

  defp scan_strings(data, offset, version) do
    case offset < byte_size(data) - 2 do
      false ->
        :ok

      true ->
        word = :binary.at(data, offset) <<< 8 ||| :binary.at(data, offset + 1)

        case plausible_start?(word) do
          false ->
            scan_strings(data, offset + 2, version)

          true ->
            {words, end_offset} = collect_zwords(data, offset)

            case length(words) > 1 do
              false ->
                scan_strings(data, offset + 2, version)

              true ->
                text = decode_zstring_list(words, version, data)

                case String.length(text) > 10 do
                  true ->
                    IO.puts("#{Integer.to_string(offset, 16)}: #{text}")
                    scan_strings(data, end_offset, version)

                  false ->
                    scan_strings(data, offset + 2, version)
                end
            end
        end
    end
  end

  defp plausible_start?(word), do: (word &&& 0x8000) == 0

  defp collect_zwords(data, offset) do
    case offset >= byte_size(data) - 1 do
      true ->
        {[], offset}

      false ->
        word = :binary.at(data, offset) <<< 8 ||| :binary.at(data, offset + 1)

        case (word &&& 0x8000) != 0 do
          true ->
            {[word], offset + 2}

          false ->
            {rest, end_off} = collect_zwords(data, offset + 2)
            {[word | rest], end_off}
        end
    end
  end

  defp decode_zstring_list(words, version, data) do
    binary = for w <- words, into: <<>>, do: <<w::16-big>>
    decode_zstring(binary, version, data)
  end
end
