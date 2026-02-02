defmodule ZDecode do
  import Bitwise

  def decode(path, offset, version) do
    data = File.read!(path)
    words = get_zwords(data, offset)
    IO.puts("Address: #{Integer.to_string(offset, 16)} (V#{version})")
    zchars = words_to_zchars(words)
    IO.puts("Z-chars: #{Enum.join(zchars, ", ")}")
    text = decode_zchars(zchars, version)
    IO.puts("Decoded: '#{text}'")
  end

  defp get_zwords(data, offset) do
    word = :binary.at(data, offset) <<< 8 ||| :binary.at(data, offset + 1)

    if (word &&& 0x8000) != 0 do
      [word]
    else
      [word | get_zwords(data, offset + 2)]
    end
  end

  defp words_to_zchars(words) do
    for w <- words, c <- [w >>> 10 &&& 31, w >>> 5 &&& 31, w &&& 31], do: c
  end

  defp decode_zchars(zchars, version) do
    a0 = "abcdefghijklmnopqrstuvwxyz" |> String.to_charlist()
    a1 = "ABCDEFGHIJKLMNOPQRSTUVWXYZ" |> String.to_charlist()

    a2 =
      if version == 1 do
        "0123456789.,!?_#'\"/\\<-:() " |> String.to_charlist()
      else
        " \r0123456789.,!?_#'\"/\\-:( )" |> String.to_charlist()
      end

    alphabets = [a0, a1, a2]

    {text, _, _} =
      Enum.reduce(zchars, {[], 0, -1}, fn z, {acc, curr, next} ->
        effective = if next != -1, do: next, else: curr

        cond do
          z == 0 ->
            {acc ++ [? ], 0, -1}

          z == 1 and version == 1 ->
            {acc ++ [?\n], 0, -1}

          z == 1 and version >= 2 ->
            {acc ++ [?[, ?A, ?B, ?B, ?R, ?]], curr, -1}

          z == 2 and version == 1 ->
            {acc, curr, 1}

          z == 3 and version == 1 ->
            {acc, curr, 2}

          z == 4 and version == 1 ->
            {acc, 1, -1}

          z == 5 and version == 1 ->
            {acc, 2, -1}

          z >= 6 ->
            char = Enum.at(alphabets, effective) |> Enum.at(z - 6)
            {acc ++ [char], curr, -1}

          true ->
            {acc, curr, next}
        end
      end)

    List.to_string(text)
  end
end

ZDecode.decode("test/fixtures/provers/czech.z5", 0x080F, 5)
