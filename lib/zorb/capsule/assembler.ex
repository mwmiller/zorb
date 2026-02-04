defmodule Zorb.Capsule.Assembler do
  @moduledoc """
  Bakes bespoke story capsules by programmatically assembling and pruning the Orb AST.
  """
  require Logger

  def assemble(story_data, module_name) do
    <<version::8, _::binary>> = story_data
    logic_ast = get_fat_ast()
    pruned_ast = prune_version_branches(logic_ast, version)
    assemble_module_ast(module_name, version, story_data, pruned_ast)
  end

  defp get_fat_ast do
    path = "lib/zorb/interpreter.ex"

    {:defmodule, _meta, [_name, [{{:__block__, _, [:do]}, {:__block__, _, body}}]]} =
      File.read!(path) |> Sourceror.parse_string!()

    Enum.reject(body, fn
      {:@, _, [{:moduledoc, _, _}]} -> true
      {:use, _, [:Orb]} -> true
      {:alias, _, _} -> true
      {:require, _, _} -> true
      {{:., _, [{:__aliases__, _, [:Orb, :Import]}, :register]}, _, _} -> true
      {{:., _, [{:__aliases__, _, [:Memory]}, :pages]}, _, _} -> true
      {:global, _, _} -> true
      _ -> false
    end)
    |> then(fn filtered_body -> {:__block__, [], filtered_body} end)
  end

  defp prune_version_branches(ast, version) do
    Macro.prewalk(ast, fn
      {:if, _meta,
       [{{:., _, [{:__aliases__, _, [:I32]}, op]}, _, [{:@, _, [{:version, _, _}]}, v]}, blocks]}
      when op in [:ge_u, :le_u, :lt_u, :eq, :ne] ->
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

  defp assemble_module_ast(module_name, version, story_data, logic_ast) do
    # Extract header fields for initial values
    {globals_base, static_memory_base, dictionary_base, abbreviations_base, object_table_base} =
      extract_header_fields(story_data)

    # Version-specific calculations
    {pas_init, oes_init, po_init, soj_init, co_init, pto_init} =
      calculate_version_constants(version)

    {ro_init, so_init} = calculate_offsets(version, story_data)

    unicode_bin = generate_unicode_binary()

    alphabets_bin =
      "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ 0123456789.,!?_#'\"/\\\\\\\\<-:() \r0123456789.,!?_#'\"/\\\\\\\\-:()"

    {hash_table_bin, table_mask} =
      generate_dictionary_hash_table(story_data, dictionary_base, version)

    quote do
      defmodule unquote(module_name) do
        use Orb
        Orb.Memory.pages(16)

        alias Orb.I32
        alias Zorb.Capsule.Host, as: ZIO
        alias Zorb.Interpreter.Types, as: T
        import Orb.DSL, except: [return: 0, return: 1]
        import Orb.Control, only: [return: 0, return: 1, block: 2]
        require Zorb.Interpreter.Types

        Orb.Import.register(Zorb.Capsule.Host)

        Orb.Memory.initial_data!(0, unquote(story_data))
        Orb.Memory.initial_data!(0x80000, unquote(unicode_bin))
        Orb.Memory.initial_data!(0x81000, unquote(alphabets_bin))
        Orb.Memory.initial_data!(0x82000, unquote(hash_table_bin))

        global do
          @pc 0
          @version unquote(version)
          @sp 0
          @fp 0
          @csp 0
          @stack_base 0x90000
          @call_stack_base 0x98000
          @globals_base unquote(globals_base)
          @static_memory_base unquote(static_memory_base)
          @dictionary_base unquote(dictionary_base)
          @object_table_base unquote(object_table_base)
          @object_table_start 0
          @abbreviations_base unquote(abbreviations_base)
          @next_alphabet -1
          @abbrev_mode 0
          @recursion_depth 0
          @packed_address_shift unquote(pas_init)
          @routine_offset unquote(ro_init)
          @string_offset unquote(so_init)
          @stream3_table 0
          @stream3_active 0
          @object_entry_size unquote(oes_init)
          @object_parent_offset unquote(po_init)
          @object_sibling_offset unquote(soj_init)
          @object_child_offset unquote(co_init)
          @object_property_table_offset unquote(pto_init)
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

        unquote(generate_lookup_dictionary_ast(table_mask))
        unquote(logic_ast)
      end
    end
  end

  defp extract_header_fields(story_data) do
    <<_v::8, _::8, _::16, dictionary_base::16, object_table_base::16, globals_base::16,
      static_memory_base::16, _::32, abbreviations_base::16, _rest::binary>> = story_data

    {globals_base, static_memory_base, dictionary_base, abbreviations_base, object_table_base}
  end

  defp calculate_version_constants(version) do
    if version <= 3, do: {1, 9, 4, 5, 6, 7}, else: {2, 14, 6, 8, 10, 12}
  end

  defp calculate_offsets(version, story_data) do
    if version in 6..7,
      do:
        (
          <<_::320, r::16, s::16, _::binary>> = story_data
          {r * 8, s * 8}
        ),
      else: {0, 0}
  end

  defp generate_lookup_dictionary_ast(table_mask) do
    quote do
      # O(1) Dictionary Lookup
      defw lookup_dictionary(w1: I32, w2: I32, w3: I32), T.Address, slot: I32, addr: I32 do
        # hash = (w1 ^ w2 ^ w3) & MASK
        slot = I32.band(I32.xor(w1, I32.xor(w2, w3)), unquote(table_mask))

        loop Search do
          # 16 bytes per slot
          addr = I32.add(0x82000, I32.shl(slot, 4))

          # Check if empty (addr == 0)
          if I32.eq(Memory.load!(I32, I32.add(addr, 12)), 0) do
            return(0)
          end

          maybe_return_dict_addr(addr, w1, w2, w3)

          slot = I32.band(I32.add(slot, 1), unquote(table_mask))
          Search.continue()
        end
      end

      defwp maybe_return_dict_addr(addr: I32, w1: I32, w2: I32, w3: I32) do
        # Compare words
        if I32.eq(Memory.load!(I32, addr), w1) and
             I32.eq(Memory.load!(I32, I32.add(addr, 4)), w2) and
             I32.eq(Memory.load!(I32, I32.add(addr, 8)), w3) do
          return(Memory.load!(I32, I32.add(addr, 12)))
        end
      end
    end
  end

  defp generate_dictionary_hash_table(story_data, dict_base, version) do
    <<_::binary-size(dict_base), num_sep::8, _::binary>> = story_data
    header_end = dict_base + 1 + num_sep
    <<_::binary-size(header_end), entry_len::8, num_entries::16, _::binary>> = story_data
    entries_start = header_end + 3

    # Use 2048 slots for up to 1024 entries to keep load factor low
    table_size = 2048
    mask = table_size - 1

    # Table entry: [w1:32, w2:32, w3:32, addr:32] = 16 bytes
    table = for _ <- 1..table_size, do: {0, 0, 0, 0}
    table = List.to_tuple(table)

    final_table =
      Enum.reduce(0..(num_entries - 1), table, fn i, acc ->
        addr = entries_start + i * entry_len

        {w1, w2, w3} =
          case {version <= 3, story_data} do
            {true, <<_::binary-size(addr), w::32, _::binary>>} ->
              {w, 0, 0}

            {false, <<_::binary-size(addr), w1::32, w2::16, _::binary>>} ->
              {w1, w2, 0}
          end

        # Simple hash
        hash = Bitwise.bxor(w1, Bitwise.bxor(w2, w3)) |> Bitwise.band(mask)

        # Linear probing
        insert_at_slot(acc, hash, w1, w2, w3, addr, mask)
      end)

    bin =
      for i <- 0..(table_size - 1), into: <<>> do
        {w1, w2, w3, addr} = elem(final_table, i)
        <<w1::32-little, w2::32-little, w3::32-little, addr::32-little>>
      end

    {bin, mask}
  end

  defp insert_at_slot(table, slot, w1, w2, w3, addr, mask) do
    case elem(table, slot) do
      {0, 0, 0, 0} ->
        put_elem(table, slot, {w1, w2, w3, addr})

      _ ->
        insert_at_slot(table, Bitwise.band(slot + 1, mask), w1, w2, w3, addr, mask)
    end
  end

  defp generate_unicode_binary do
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
