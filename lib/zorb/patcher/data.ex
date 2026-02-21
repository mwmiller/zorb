defmodule Zorb.Patcher.Data do
  @moduledoc """
  Extracts patchable data from Z-machine story files.
  This data is used to patch pre-compiled WASM templates.
  """

  alias Zorb.Capsule.Assembler

  @doc """
  Extract all data needed to patch a WASM template for the given story.

  Returns a map with:
  - `:globals` - Map of global indices to values (for Watusi.Patcher)
  - `:data_segments` - List of {offset, binary} tuples for memory segments
  """
  def extract(story_data) do
    <<version::8, _::binary>> = story_data

    # Extract header fields
    {gb, smb, db, ab, otb} = Assembler.extract_header_fields(story_data)
    {pas, oes, po, soj, co, pto} = Assembler.calculate_version_constants(version)
    {ro, so} = Assembler.calculate_offsets(version, story_data)

    # Generate story-specific data
    {hash_table, _mask} = Assembler.generate_dictionary_hash_table(story_data, db, version)

    unicode =
      case version >= 5 do
        true -> Assembler.generate_unicode_binary()
        false -> <<>>
      end

    alphabets = generate_alphabets(version)
    metadata = generate_metadata(story_data)

    # Map global names to their indices in the WASM global section
    # Order must match the global block in assembler.ex lines 141-170
    globals_by_index = %{
      # 0: @pc (not patchable, always 0)
      1 => version,
      # 2: @sp, 3: @fp, 4: @csp, 5: @stack_base, 6: @call_stack_base (not patchable)
      7 => gb,
      8 => smb,
      9 => db,
      10 => otb,
      11 => if(version <= 3, do: otb + 62, else: otb + 126),
      12 => ab,
      # 13: @next_alphabet, 14: @abbrev_mode, 15: @recursion_depth (not patchable)
      16 => pas,
      17 => ro,
      18 => so,
      # 19: @stream3_table, 20: @stream3_active (not patchable)
      21 => oes,
      22 => po,
      23 => soj,
      24 => co,
      25 => pto,
      # 26: @random_state (not patchable)
      27 => byte_size(story_data)
      # 28+: @capabilities, @zscii_state, etc. (not patchable)
    }

    %{
      globals: globals_by_index,
      data_segments: [
        {0x00000, story_data},
        {0x80000, unicode},
        {0x81000, alphabets},
        {0x82000, hash_table},
        {0x8A000, metadata}
      ]
    }
  end

  defp generate_alphabets(version) do
    a0 = Enum.to_list(?a..?z)
    a1 = Enum.to_list(?A..?Z)

    a2_v1 = [
      ?\s,
      ?0,
      ?1,
      ?2,
      ?3,
      ?4,
      ?5,
      ?6,
      ?7,
      ?8,
      ?9,
      ?.,
      ?,,
      ?!,
      ??,
      ?_,
      ?#,
      ?',
      ?\",
      ?/,
      ?\\,
      ?<,
      ?-,
      ?:,
      ?(,
      ?)
    ]

    a2_v2 = [
      0,
      13,
      ?0,
      ?1,
      ?2,
      ?3,
      ?4,
      ?5,
      ?6,
      ?7,
      ?8,
      ?9,
      ?.,
      ?,,
      ?!,
      ??,
      ?_,
      ?#,
      ?',
      ?\",
      ?/,
      ?\\,
      ?-,
      ?:,
      ?(,
      ?)
    ]

    alphabets =
      case version do
        1 -> a0 ++ a1 ++ a2_v1 ++ List.duplicate(0, 26)
        _ -> a0 ++ a1 ++ List.duplicate(0, 26) ++ a2_v2
      end

    :binary.list_to_bin(alphabets)
  end

  defp generate_metadata(story_data) do
    metadata = Zorb.Inspector.analyze(story_data)

    <<metadata.version::8, metadata.serial::binary-size(6), 0::8, metadata.command_prefix::8,
      0::56>> <>
      String.pad_trailing(String.slice(metadata.chat_prefix, 0, 63), 64, <<0>>) <>
      String.pad_trailing(String.slice(metadata.channel_prefix, 0, 63), 64, <<0>>)
  end
end
