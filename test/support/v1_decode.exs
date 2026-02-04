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
    alphabets = build_alphabets(version)

    {text, _, _} =
      Enum.reduce(zchars, {[], 0, -1}, fn z, {acc, curr, next} ->
        effective = if next != -1, do: next, else: curr
        apply_zchar(z, version, acc, curr, next, effective, alphabets)
      end)

    List.to_string(text)
  end

  defp build_alphabets(version) do
    a0 = "abcdefghijklmnopqrstuvwxyz" |> String.to_charlist()
    a1 = "ABCDEFGHIJKLMNOPQRSTUVWXYZ" |> String.to_charlist()

    a2 =
      if version == 1 do
        "0123456789.,!?_#'\"/\\<-:() " |> String.to_charlist()
      else
        " \r0123456789.,!?_#'\"/\\-:( )" |> String.to_charlist()
      end

    [a0, a1, a2]
  end

  defp apply_zchar(0, _version, acc, _curr, _next, _effective, _alphabets),
    do: {acc ++ [? ], 0, -1}

  defp apply_zchar(1, 1, acc, _curr, _next, _effective, _alphabets), do: {acc ++ [?\n], 0, -1}

  defp apply_zchar(1, version, acc, curr, _next, _effective, _alphabets) when version >= 2 do
    {acc ++ [?[, ?A, ?B, ?B, ?R, ?]], curr, -1}
  end

  defp apply_zchar(2, 1, acc, curr, _next, _effective, _alphabets), do: {acc, curr, 1}
  defp apply_zchar(3, 1, acc, curr, _next, _effective, _alphabets), do: {acc, curr, 2}
  defp apply_zchar(4, 1, acc, _curr, _next, _effective, _alphabets), do: {acc, 1, -1}
  defp apply_zchar(5, 1, acc, _curr, _next, _effective, _alphabets), do: {acc, 2, -1}

  defp apply_zchar(z, _version, acc, curr, _next, effective, alphabets) when z >= 6 do
    char = Enum.at(alphabets, effective) |> Enum.at(z - 6)
    {acc ++ [char], curr, -1}
  end

  defp apply_zchar(_z, _version, acc, curr, next, _effective, _alphabets), do: {acc, curr, next}
end

ZDecode.decode("test/fixtures/provers/czech.z5", 0x080F, 5)
