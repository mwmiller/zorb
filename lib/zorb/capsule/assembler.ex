defmodule Zorb.Capsule.Assembler do
  @moduledoc """
  Bakes bespoke story capsules by programmatically assembling and pruning the Orb AST using Sourceror.
  """
  require Logger

  def assemble(story_data, module_name) do
    <<version::8, _::binary>> = story_data

    # 1. Read fat AST
    path = "lib/zorb/interpreter.ex"
    source = File.read!(path)
    ast = Sourceror.parse_string!(source)

    # 2. Prepare Data
    {gb, smb, db, ab, otb} = extract_header_fields(story_data)
    {hash_table, mask} = generate_dictionary_hash_table(story_data, db, version)
    pruned_story = prune_story_data(story_data, dictionary_base: db)
    {pas, oes, po, _soj, co, pto} = calculate_version_constants(version)
    {ro, so} = calculate_offsets(version, story_data)
    unicode = generate_unicode_binary()

    alphabets =
      "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ 0123456789.,!?_#'\"/\\\\\\\\<-:() \r0123456789.,!?_#'\"/\\\\\\\\-:()"

    # 3. Create Replacement ASTs
    new_global_block =
      quote do
        global do
          @pc 0
          @version unquote(version)
          @sp 0
          @fp 0
          @csp 0
          @stack_base 0x90000
          @call_stack_base 0x98000
          @globals_base unquote(gb)
          @static_memory_base unquote(smb)
          @dictionary_base unquote(db)
          @object_table_base unquote(otb)
          @object_table_start 0
          @abbreviations_base unquote(ab)
          @next_alphabet -1
          @abbrev_mode 0
          @recursion_depth 0
          @packed_address_shift unquote(pas)
          @routine_offset unquote(ro)
          @string_offset unquote(so)
          @stream3_table 0
          @stream3_active 0
          @object_entry_size unquote(oes)
          @object_parent_offset unquote(po)
          @object_sibling_offset unquote(so)
          @object_child_offset unquote(co)
          @object_property_table_offset unquote(pto)
          @random_state 1
          @story_len unquote(byte_size(story_data))
          @capabilities 0
          @zscii_state 0
          @zscii_high 0
          @unicode_table_base 0x80000
          @current_font 1
          @current_alphabet 0
          @halted 0
          @encoded_w1 0
          @encoded_w2 0
          @encoded_w3 0
        end
      end

    new_memory_setup =
      quote do
        Orb.Memory.pages(16)
        Orb.Memory.initial_data!(0, var!(bespoke_story_data))
        Orb.Memory.initial_data!(0x80000, var!(bespoke_unicode_bin))
        Orb.Memory.initial_data!(0x81000, var!(bespoke_alphabets_bin))
        Orb.Memory.initial_data!(0x82000, var!(bespoke_hash_table_bin))
      end

    new_lookup_dictionary =
      quote do
        defw lookup_dictionary(w1: I32, w2: I32, w3: I32), T.Address, slot: I32, addr: I32 do
          slot = I32.band(I32.xor(w1, I32.xor(w2, w3)), unquote(mask))

          loop Search do
            addr = I32.add(0x82000, I32.shl(slot, 4))

            if I32.eq(Memory.load!(I32, I32.add(addr, 12)), 0) do
              return(0)
            end

            maybe_return_dict_addr(addr, w1, w2, w3)

            slot = I32.band(I32.add(slot, 1), unquote(mask))
            Search.continue()
          end
        end
      end

    # 4. Transform AST
    final_ast =
      ast
      |> rename_module(module_name)
      |> replace_globals(new_global_block)
      |> replace_lookup_dictionary(new_lookup_dictionary)
      |> prune_and_inject_memory(new_memory_setup)
      |> prune_version_branches(version)

    # 5. Convert to String
    source_code = Sourceror.to_string(final_ast)

    # 6. Return Source and Data
    data = %{
      bespoke_story_data: pruned_story,
      bespoke_unicode_bin: unicode,
      bespoke_alphabets_bin: alphabets,
      bespoke_hash_table_bin: hash_table
    }

    {source_code, data}
  end

  def prune_version_branches(ast, version) do
    Macro.prewalk(ast, fn
      {:if, _meta,
       [{{:., _, [{:__aliases__, _, aliases}, op]}, _, [{:@, _, [{:version, _, _}]}, v]}, blocks]}
      when op in [:ge_u, :le_u, :lt_u, :eq, :ne] and aliases in [[:I32], [:Orb, :I32]] ->
        yes = blocks[:do]
        no = blocks[:else] || quote(do: Orb.DSL.nop())

        take_yes =
          case op do
            :ge_u -> version >= v
            :le_u -> version <= v
            :lt_u -> version < v
            :eq -> version == v
            :ne -> version != v
          end

        if take_yes, do: yes, else: no

      nil ->
        quote(do: Orb.DSL.nop())

      node ->
        node
    end)
  end

  defp rename_module(ast, new_name) do
    alias_node =
      {:__aliases__, [alias: false], Module.split(new_name) |> Enum.map(&String.to_atom/1)}

    Macro.prewalk(ast, fn
      {:defmodule, meta, [_old_name, args]} ->
        {:defmodule, meta, [alias_node, args]}

      node ->
        node
    end)
  end

  defp replace_globals(ast, new_globals) do
    Macro.prewalk(ast, fn
      {:global, _, [[do: _]]} -> new_globals
      node -> node
    end)
  end

  defp replace_lookup_dictionary(ast, new_def) do
    Macro.prewalk(ast, fn
      {:defw, _, [{:lookup_dictionary, _, _} | _]} -> new_def
      node -> node
    end)
  end

  defp prune_and_inject_memory(ast, new_setup) do
    Macro.prewalk(ast, fn
      {:defmodule, meta, [name, [do: {:__block__, bmeta, children}]]} ->
        filtered_children =
          Enum.reject(children, fn
            {{:., _, [{:__aliases__, _, [:Memory]}, :pages]}, _, _} -> true
            {{:., _, [{:__aliases__, _, [:Memory]}, :initial_data!]}, _, _} -> true
            {{:., _, [{:__aliases__, _, [:Orb, :Memory]}, :initial_data!]}, _, _} -> true
            _ -> false
          end)

        final_children = inject_after_use_orb(filtered_children, new_setup)

        {:defmodule, meta, [name, [do: {:__block__, bmeta, final_children}]]}

      node ->
        node
    end)
  end

  defp inject_after_use_orb(children, new_setup) do
    index =
      Enum.find_index(children, fn
        {:use, _, [{:__aliases__, _, [:Orb]}]} -> true
        _ -> false
      end)

    case index do
      nil -> [new_setup | children]
      i -> List.insert_at(children, i + 1, new_setup)
    end
  end

  def extract_header_fields(story_data) do
    <<_v::8, _f1::8, _rel::16, _hmb::16, _pc::16, dictionary_base::16, object_table_base::16,
      globals_base::16, static_memory_base::16, _f2::16, _serial::binary-size(6),
      abbreviations_base::16, _rest::binary>> = story_data

    {globals_base, static_memory_base, dictionary_base, abbreviations_base, object_table_base}
  end

  def calculate_version_constants(version) do
    if version <= 3, do: {1, 9, 4, 5, 6, 7}, else: {2, 14, 6, 8, 10, 12}
  end

  def calculate_offsets(version, story_data) do
    if version in 6..7,
      do:
        (
          <<_::320, r::16, s::16, _::binary>> = story_data
          {r * 8, s * 8}
        ),
      else: {0, 0}
  end

  def prune_story_data(data, opts) do
    dict_base = Keyword.fetch!(opts, :dictionary_base)
    <<_::binary-size(dict_base), num_sep::8, _::binary>> = data
    header_end = dict_base + 1 + num_sep
    <<_::binary-size(header_end), entry_len::8, num_entries::16, _::binary>> = data
    entries_start = header_end + 3
    entries_len = num_entries * entry_len
    <<prefix::binary-size(entries_start), _::binary-size(entries_len), suffix::binary>> = data
    prefix <> <<0::size(entries_len)-unit(8)>> <> suffix
  end

  def generate_dictionary_hash_table(story_data, dict_base, version) do
    <<_::binary-size(dict_base), num_sep::8, _::binary>> = story_data
    header_end = dict_base + 1 + num_sep
    <<_::binary-size(header_end), entry_len::8, num_entries::16, _::binary>> = story_data
    entries_start = header_end + 3

    table_size = 2048
    mask = table_size - 1
    table = for _ <- 1..table_size, do: {0, 0, 0, 0}
    table = List.to_tuple(table)

    final_table =
      Enum.reduce(0..max(0, num_entries - 1), table, fn i, acc ->
        if num_entries == 0 do
          acc
        else
          addr = entries_start + i * entry_len
          {w1, w2, w3} = get_encoded_words(story_data, addr, version)
          hash = Bitwise.bxor(w1, Bitwise.bxor(w2, w3)) |> Bitwise.band(mask)
          insert_at_slot(acc, hash, w1, w2, w3, addr, mask)
        end
      end)

    bin =
      for i <- 0..(table_size - 1), into: <<>> do
        {w1, w2, w3, addr} = elem(final_table, i)
        <<w1::32-little, w2::32-little, w3::32-little, addr::32-little>>
      end

    {bin, mask}
  end

  defp get_encoded_words(story_data, addr, version) do
    if version <= 3 do
      <<_::binary-size(addr), w::32, _::binary>> = story_data
      {w, 0, 0}
    else
      <<_::binary-size(addr), w1::32, w2::16, _::binary>> = story_data
      {w1, w2, 0}
    end
  end

  defp insert_at_slot(table, slot, w1, w2, w3, addr, mask) do
    case elem(table, slot) do
      {0, 0, 0, 0} -> put_elem(table, slot, {w1, w2, w3, addr})
      _ -> insert_at_slot(table, Bitwise.band(slot + 1, mask), w1, w2, w3, addr, mask)
    end
  end

  def generate_unicode_binary do
    table = [
      0x00E4,
      0x00F6,
      0x00FC,
      0x00C4,
      0x00D6,
      0x00DC,
      0x00DF,
      0x00BB,
      0x00AB,
      0x00EB,
      0x00EF,
      0x00FF,
      0x00CB,
      0x00CF,
      0x00E1,
      0x00E9,
      0x00ED,
      0x00F3,
      0x00FA,
      0x00FD,
      0x00C1,
      0x00C9,
      0x00CD,
      0x00D3,
      0x00DA,
      0x00DD,
      0x00E0,
      0x00E8,
      0x00EC,
      0x00F2,
      0x00F9,
      0x00C0,
      0x00C8,
      0x00CC,
      0x00D2,
      0x00D9,
      0x00E2,
      0x00EA,
      0x00EE,
      0x00F4,
      0x00FB,
      0x00C2,
      0x00CA,
      0x00CE,
      0x00D4,
      0x00DB,
      0x00E5,
      0x00C5,
      0x00F8,
      0x00D8,
      0x00E3,
      0x00F1,
      0x00F5,
      0x00C3,
      0x00D1,
      0x00D5,
      0x00E6,
      0x00C6,
      0x00E7,
      0x00C7,
      0x00FE,
      0x00F0,
      0x00DE,
      0x00D0,
      0x00A3,
      0x0153,
      0x0152,
      0x00A1,
      0x00BF,
      0x00AA,
      0x00BA,
      0x00E6,
      0x00C6,
      0x00F8,
      0x00D8,
      0x00E5,
      0x00C5,
      0x00E7,
      0x00C7,
      0x00F0,
      0x00D0,
      0x00F1,
      0x00D1,
      0x00F5,
      0x00D5,
      0x00FE,
      0x00DE,
      0x00A9,
      2122,
      0x20AC,
      0x0024,
      0x0192,
      0x03B1,
      0x03B2,
      0x03B3,
      0x03B4,
      0x03B5,
      0x03B6,
      0x03B7,
      0x03B8,
      0x03B9,
      0x03BA,
      0x03BB,
      0x03BC,
      0x03BD,
      0x03BE,
      0x03BF,
      0x03C0,
      0x03C1,
      0x03C2,
      0x03C3,
      0x03C4,
      0x03C5,
      0x03C6,
      0x03C7,
      0x03C8,
      0x03C9,
      0x0391,
      0x0392,
      0x0393,
      0x0394,
      0x0395,
      0x0396,
      0x0397,
      0x0398,
      0x0399,
      0x039A,
      0x039B,
      0x039C,
      0x039D,
      0x039E,
      0x039F,
      0x03A0,
      0x03A1,
      0x03A3,
      0x03A4,
      0x03A5,
      0x03A6,
      0x03A7,
      0x03A8,
      0x03A9
    ]

    for u <- table, into: <<>>, do: <<u::16-big>>
  end
end
