defmodule Zorb.Inspector do
  @moduledoc """
  Specialized tool for story analysis and metadata extraction.
  """

  @doc """
  Analyzes a Z-machine story file and returns a metadata map.
  """
  def analyze(story_data) do
    <<version::8, _::8, _rel::16, _hmb::16, _pc::16, dict_base::16, _::binary-size(10),
      serial::binary-size(6), _::binary>> =
      story_data

    <<_::binary-size(dict_base), num_sep::8, seps::binary-size(num_sep), _::binary>> = story_data
    sep_list = :binary.bin_to_list(seps)

    # Use /, ~, ., - in that order if they are NOT used by the dictionary.
    prefix = Enum.find([?/, ?~, ?., ?-], &(&1 not in sep_list)) || ?.

    # Semantic analysis for Orbit Radio
    tag = determine_radio_tag(story_data, version)
    users = determine_user_word(story_data, version)

    %{
      version: version,
      serial: serial,
      command_prefix: prefix,
      chat_prefix: tag,
      channel_prefix: users
    }
  end

  defp determine_radio_tag(story_data, version) do
    words = extract_dictionary_words(story_data, version)

    tag_candidates = [
      {"RADIO", ["radio", "phon", "broad"]},
      {"COMM", ["comm", "signal", "link", "net", "freq"]},
      {"WAVE", ["wave", "beam", "pulse", "data"]},
      {"ORB", ["orb", "stone", "crystal", "mirror"]},
      {"SPELL", ["spell", "scroll", "magic", "rune"]},
      {"MIND", ["mind", "thought", "dream", "soul"]},
      {"VOICE", ["voice", "sound", "talk", "word"]},
      {"NOTE", ["note", "sign", "mark", "page"]},
      {"CALL", ["call", "hail", "shout", "yell"]},
      {"STAR", ["star", "sun", "moon", "sky"]},
      {"DECK", ["deck", "card", "play", "game"]},
      {"BOOK", ["book", "read", "text", "libr"]},
      {"MAP", ["map", "chart", "locat", "find"]},
      {"GEAR", ["gear", "tool", "item", "thing"]},
      {"SHIP", ["ship", "boat", "vessel", "craft"]},
      {"ROOM", ["room", "area", "place", "zone"]},
      {"TIME", ["time", "clock", "watch", "hour"]}
    ]

    case find_best_match(words, tag_candidates) do
      {label, _found_word} ->
        label

      nil ->
        "ZORB"
    end
  end

  defp determine_user_word(story_data, version) do
    words = extract_dictionary_words(story_data, version)

    # Short 4-5 letter user labels
    user_candidates = [
      {"FOLKS", ["folk"]},
      {"SOULS", ["soul"]},
      {"MATES", ["mate", "fellow"]},
      {"HERO", ["hero"]},
      {"CHUMS", ["friend"]},
      {"PEEPS", ["peopl"]},
      {"PARTY", ["advent"]},
      {"USER", ["user"]},
      {"GUEST", ["guest"]},
      {"BEING", ["being", "creat"]},
      {"ALIEN", ["alien"]},
      {"PILOT", ["pilot"]},
      {"CHIEF", ["chief"]},
      {"GUARD", ["guard"]},
      {"SCOUT", ["scout"]},
      {"ELDER", ["elder"]},
      {"CREW", ["others"]}
    ]

    case find_best_match(words, user_candidates) do
      {label, _found_word} ->
        label

      nil ->
        "USER"
    end
  end

  defp find_best_match(dictionary_words, candidates) do
    Enum.find_value(candidates, nil, fn {label, prefixes} ->
      found_word =
        Enum.find(dictionary_words, fn dw ->
          Enum.any?(prefixes, &String.starts_with?(dw, &1))
        end)

      if found_word, do: {label, found_word}, else: nil
    end)
  end

  defp extract_dictionary_words(story_data, version) do
    import Bitwise

    <<_::8, _::8, _::16, _::16, _::16, dict_base::16, _::binary>> = story_data

    <<_::binary-size(dict_base), num_sep::8, _::binary-size(num_sep), entry_len::8,
      num_entries::16, entries::binary>> = story_data

    # Limit scanning for efficiency if dictionary is huge, but scan enough for metadata.
    if num_entries > 0 do
      num_to_scan = min(num_entries, 2048)

      for i <- 0..(num_to_scan - 1) do
        addr = i * entry_len
        extract_word(entries, addr, version)
      end
      |> Enum.uniq()
    else
      []
    end
  end

  defp extract_word(entries, addr, version) do
    import Bitwise

    if version <= 3 do
      <<w1::16-big, w2::16-big, _::binary>> = binary_part(entries, addr, 4)

      decode_zchars([
        w1 >>> 10 &&& 31,
        w1 >>> 5 &&& 31,
        w1 &&& 31,
        w2 >>> 10 &&& 31,
        w2 >>> 5 &&& 31,
        w2 &&& 31
      ])
    else
      <<w1::16-big, w2::16-big, w3::16-big, _::binary>> = binary_part(entries, addr, 6)

      decode_zchars([
        w1 >>> 10 &&& 31,
        w1 >>> 5 &&& 31,
        w1 &&& 31,
        w2 >>> 10 &&& 31,
        w2 >>> 5 &&& 31,
        w2 &&& 31,
        w3 >>> 10 &&& 31,
        w3 >>> 5 &&& 31,
        w3 &&& 31
      ])
    end
  end

  defp decode_zchars(zchars) do
    Enum.map_join(zchars, "", fn z ->
      if z >= 6 and z <= 31, do: <<?a + z - 6>>, else: ""
    end)
  end
end
