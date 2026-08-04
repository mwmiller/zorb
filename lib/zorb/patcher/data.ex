defmodule Zorb.Patcher.Data do
  @moduledoc """
  Extracts patchable data from Z-machine story files.
  This data is used to patch pre-compiled WASM templates.
  """

  alias Zorb.Capsule.Assembler

  @doc """
  Extract all data needed to patch a WASM template for the given story.

  Returns a keyword list with:
  - `:globals` - Map of global indices to values (for Watusi.Patcher)
  - `:data` - List of {offset, binary} tuples for memory segments
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

    alphabets = Assembler.generate_alphabets(version) |> :binary.list_to_bin()
    metadata = Assembler.generate_metadata_binary(story_data)

    # Map global names to their indices in the WASM global section
    # Order must match the global block in assemble/2 (global_block_ast)
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

    [
      globals: globals_by_index,
      data: [
        {0x00000, story_data},
        {0x80000, unicode},
        {0x81000, alphabets},
        {0x82000, hash_table},
        {0x8A000, metadata}
      ]
    ]
  end
end
