defmodule Zorb.Capsule.Assembler do
  # credo:disable-for-this-file Credo.Check.Refactor.CyclomaticComplexity
  # credo:disable-for-this-file Credo.Check.Refactor.Nesting
  # credo:disable-for-this-file Credo.Check.Refactor.LongQuoteBlocks
  @moduledoc """
  Bakes bespoke story capsules by programmatically assembling and pruning the Orb AST using Sourceror.
  """
  require Logger

  @interpreter_source_path Path.expand("../interpreter.ex", __DIR__)
  @external_resource @interpreter_source_path
  @interpreter_ast Sourceror.parse_string!(File.read!(@interpreter_source_path))

  defp fat_ast, do: unquote(Macro.escape(@interpreter_ast))

  def assemble(story_data, module_name) do
    <<version::8, _::binary>> = story_data

    # 1. Read fat AST
    ast = fat_ast()

    # 2. Prepare Data
    {gb, smb, db, ab, otb} = extract_header_fields(story_data)
    {hash_table, mask} = generate_dictionary_hash_table(story_data, db, version)
    pruned_story = prune_story_data(story_data, dictionary_base: db)
    {pas, oes, po, soj, co, pto} = calculate_version_constants(version)
    {ro, so} = calculate_offsets(version, story_data)
    unicode = generate_unicode_binary()

    # Spec 3.5.3: Alphabets. Note: zchars 0-5 are special, table starts at zchar 6.
    a0 = Enum.to_list(?a..?z)
    a1 = Enum.to_list(?A..?Z)

    # V1 A2: Spec 3.5.4
    a2_v1 = [
      ?\s, ?0, ?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?., ?,, ?!, ??, ?_, ?#, ?', ?\", ?/, ?\\, ?<, ?-, ?:, ?(, ?)
    ]

    # V2+ A2: Spec 3.5.3
    a2_v2 = [
      0, 13, ?0, ?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?., ?,, ?!, ??, ?_, ?#, ?', ?\", ?/, ?\\, ?-, ?:, ?(, ?)
    ]

    alphabets = a0 ++ a1 ++ a2_v1 ++ a2_v2
    if length(alphabets) != 104, do: raise("Wrong alphabet size: #{length(alphabets)}")

    # 3. Create Replacement ASTs
    host_registration_ast = quote(do: Orb.Import.register(Zorb.Capsule.Host))

    global_block_ast =
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
          @object_table_start unquote(if version <= 3, do: otb + 62, else: otb + 126)
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
          @object_sibling_offset unquote(soj)
          @object_child_offset unquote(co)
          @object_property_table_offset unquote(pto)
          @random_state 1
          @story_len unquote(byte_size(story_data))
          @capabilities 0
          @zscii_state 0
          @zscii_high 0
          @unicode_table_base 0
          @current_font 1
          @current_alphabet 0
          @halted 0
          @tick 0
        end
      end

    memory_setup_ast =
      [
        quote(do: Orb.Memory.pages(16))
        | chunk_initial_data(0, pruned_story) ++
            [
              quote(
                do: Orb.Memory.initial_data!(0x80000, u8: unquote(:binary.bin_to_list(unicode)))
              ),
              quote(do: Orb.Memory.initial_data!(0x81000, u8: unquote(alphabets))),
              quote(
                do:
                  Orb.Memory.initial_data!(0x82000, u8: unquote(:binary.bin_to_list(hash_table)))
              )
            ]
      ]
      |> List.flatten()

    ldict_definition_ast =
      quote do
        defw ldict(w1: I32, w2: I32, w3: I32), T.Address, slot: I32, addr: I32 do
          slot = I32.band(I32.xor(w1, I32.xor(w2, w3)), unquote(mask))

          loop Search do
            addr = I32.add(0x82000, I32.shl(slot, 4))

            if I32.eq(Memory.load!(I32, I32.add(addr, 12)), 0) do
              return(0)
            end

            if mdict(addr, w1, w2, w3) do
              return(Memory.load!(I32, I32.add(addr, 12)))
            end

            slot = I32.band(I32.add(slot, 1), unquote(mask))
            Search.continue()
          end

          return(0)
        end
      end

    mdict_definition_ast =
      quote do
        defw mdict(addr: T.Address, w1: I32, w2: I32, w3: I32), I32, combined1: I32 do
          combined1 = I32.or(I32.shl(w1, 16), w2)

          if I32.ne(Memory.load!(I32, addr), combined1) do
            return(0)
          end

          if I32.ne(Memory.load!(I32, I32.add(addr, 4)), w3) do
            return(0)
          end

          return(1)
        end
      end

    do_tokenise_definition_ast =
      quote do
        defw do_tokenise(t: T.Address, p: T.Address, d: T.Address),
          text_start: I32,
          text_len: I32,
          max_words: I32,
          word_count: I32,
          i: I32,
          char: I32,
          in_word: I32,
          word_start: I32,
          word_len: I32,
          parse_idx: I32,
          dict_addr: T.Address,
          num_sep: I32,
          sep_addr: I32,
          j: I32,
          k: I32,
          sep_char: I32,
          is_sep: I32,
          zchars_len: I32,
          zchar: I32,
          w1: I32,
          w2: I32,
          w3: I32,
          z0: I32,
          z1: I32,
          z2: I32,
          z3: I32,
          z4: I32,
          z5: I32,
          z6: I32,
          z7: I32,
          z8: I32,
          alph_addr: I32,
          found: I32 do
          if I32.eq(d, 0), do: d = @dictionary_base

          if I32.ge_u(@version, 5) do
            text_start = I32.add(t, 2)
            text_len = read_byte(I32.add(t, 1))
          else
            text_start = I32.add(t, 1)
            text_len = 0

            Control.block FindNullBlock do
              loop FindNull do
                if I32.lt_u(text_len, 255) do
                  if I32.eq(read_byte(I32.add(text_start, text_len)), 0) do
                    FindNullBlock.break()
                  end

                  text_len = I32.add(text_len, 1)
                  FindNull.continue()
                end
              end
            end
          end

          max_words = read_byte(p)
          word_count = 0
          num_sep = read_byte(d)
          sep_addr = I32.add(d, 1)

          i = 0
          in_word = 0
          word_start = 0
          word_len = 0

          loop TokenLoop do
            if I32.lt_u(i, text_len) do
              char = read_byte(I32.add(text_start, i))
              is_sep = 0

              if I32.gt_u(num_sep, 0) do
                j = 0

                Control.block SepLoopBlock do
                  loop SepLoop do
                    if I32.lt_u(j, num_sep) do
                      sep_char = read_byte(I32.add(sep_addr, j))

                      if I32.eq(char, sep_char) do
                        is_sep = 1
                        SepLoopBlock.break()
                      end

                      j = I32.add(j, 1)
                      SepLoop.continue()
                    end
                  end
                end
              end

              if I32.or(I32.eq(char, 32), is_sep) do
                if in_word do
                  if I32.lt_u(word_count, max_words) do
                    z0 = 5
                    z1 = 5
                    z2 = 5
                    z3 = 5
                    z4 = 5
                    z5 = 5
                    z6 = 5
                    z7 = 5
                    z8 = 5
                    zchars_len = 0
                    j = 0

                    loop EncodeLoop do
                      if I32.band(
                           I32.lt_u(j, word_len),
                           I32.lt_u(
                             zchars_len,
                             if(I32.le_u(@version, 3), do: I32.const(6), else: I32.const(9))
                           )
                         ) do
                        char = read_byte(I32.add(text_start, I32.add(word_start, j)))

                        if I32.band(I32.ge_u(char, 65), I32.le_u(char, 90)) do
                          char = I32.add(char, 32)
                        end

                        found = 0

                        if I32.eq(char, 32) do
                          if I32.lt_u(
                               zchars_len,
                               if(I32.le_u(@version, 3), do: I32.const(6), else: I32.const(9))
                             ) do
                            zchar = 0
                            if I32.eq(zchars_len, 0), do: z0 = zchar
                            if I32.eq(zchars_len, 1), do: z1 = zchar
                            if I32.eq(zchars_len, 2), do: z2 = zchar
                            if I32.eq(zchars_len, 3), do: z3 = zchar
                            if I32.eq(zchars_len, 4), do: z4 = zchar
                            if I32.eq(zchars_len, 5), do: z5 = zchar
                            if I32.eq(zchars_len, 6), do: z6 = zchar
                            if I32.eq(zchars_len, 7), do: z7 = zchar
                            if I32.eq(zchars_len, 8), do: z8 = zchar
                            zchars_len = I32.add(zchars_len, 1)
                          end

                          found = 1
                        end

                        if I32.band(I32.eq(found, 0), I32.band(I32.ge_u(char, 97), I32.le_u(char, 122))) do
                          zchar = I32.add(I32.sub(char, 97), 6)

                          if I32.lt_u(
                               zchars_len,
                               if(I32.le_u(@version, 3), do: I32.const(6), else: I32.const(9))
                             ) do
                            if I32.eq(zchars_len, 0), do: z0 = zchar
                            if I32.eq(zchars_len, 1), do: z1 = zchar
                            if I32.eq(zchars_len, 2), do: z2 = zchar
                            if I32.eq(zchars_len, 3), do: z3 = zchar
                            if I32.eq(zchars_len, 4), do: z4 = zchar
                            if I32.eq(zchars_len, 5), do: z5 = zchar
                            if I32.eq(zchars_len, 6), do: z6 = zchar
                            if I32.eq(zchars_len, 7), do: z7 = zchar
                            if I32.eq(zchars_len, 8), do: z8 = zchar
                            zchars_len = I32.add(zchars_len, 1)
                          end

                          found = 1
                        end

                        if I32.eq(found, 0) do
                          k = 0

                          Control.block A1Search do
                            loop A1Loop do
                              if I32.lt_u(k, 26) do
                                if I32.eq(read_byte(I32.add(0x8101A, k)), char) do
                                  zchar =
                                    if(I32.le_u(@version, 2), do: I32.const(2), else: I32.const(4))

                                  if I32.lt_u(
                                       zchars_len,
                                       if(I32.le_u(@version, 3), do: I32.const(6), else: I32.const(9))
                                     ) do
                                    if I32.eq(zchars_len, 0), do: z0 = zchar
                                    if I32.eq(zchars_len, 1), do: z1 = zchar
                                    if I32.eq(zchars_len, 2), do: z2 = zchar
                                    if I32.eq(zchars_len, 3), do: z3 = zchar
                                    if I32.eq(zchars_len, 4), do: z4 = zchar
                                    if I32.eq(zchars_len, 5), do: z5 = zchar
                                    if I32.eq(zchars_len, 6), do: z6 = zchar
                                    if I32.eq(zchars_len, 7), do: z7 = zchar
                                    if I32.eq(zchars_len, 8), do: z8 = zchar
                                    zchars_len = I32.add(zchars_len, 1)
                                  end

                                  zchar = I32.add(k, 6)

                                  if I32.lt_u(
                                       zchars_len,
                                       if(I32.le_u(@version, 3), do: I32.const(6), else: I32.const(9))
                                     ) do
                                    if I32.eq(zchars_len, 0), do: z0 = zchar
                                    if I32.eq(zchars_len, 1), do: z1 = zchar
                                    if I32.eq(zchars_len, 2), do: z2 = zchar
                                    if I32.eq(zchars_len, 3), do: z3 = zchar
                                    if I32.eq(zchars_len, 4), do: z4 = zchar
                                    if I32.eq(zchars_len, 5), do: z5 = zchar
                                    if I32.eq(zchars_len, 6), do: z6 = zchar
                                    if I32.eq(zchars_len, 7), do: z7 = zchar
                                    if I32.eq(zchars_len, 8), do: z8 = zchar
                                    zchars_len = I32.add(zchars_len, 1)
                                  end

                                  found = 1
                                  A1Search.break()
                                end

                                k = I32.add(k, 1)
                                A1Loop.continue()
                              end
                            end
                          end
                        end

                        if I32.eq(found, 0) do
                          alph_addr = 0x81034
                          if I32.ne(@version, 1) do
                            alph_addr = 0x8104E
                          end

                          k = 0

                          Control.block A2Search do
                            loop A2Loop do
                              if I32.lt_u(k, 26) do
                                if I32.eq(read_byte(I32.add(alph_addr, k)), char) do
                                  if I32.ne(k, 0) do
                                    zchar =
                                      if(I32.le_u(@version, 2),
                                        do: I32.const(3),
                                        else: I32.const(5)
                                      )

                                    if I32.lt_u(
                                         zchars_len,
                                         if(I32.le_u(@version, 3),
                                           do: I32.const(6),
                                           else: I32.const(9)
                                         )
                                       ) do
                                      if I32.eq(zchars_len, 0), do: z0 = zchar
                                      if I32.eq(zchars_len, 1), do: z1 = zchar
                                      if I32.eq(zchars_len, 2), do: z2 = zchar
                                      if I32.eq(zchars_len, 3), do: z3 = zchar
                                      if I32.eq(zchars_len, 4), do: z4 = zchar
                                      if I32.eq(zchars_len, 5), do: z5 = zchar
                                      if I32.eq(zchars_len, 6), do: z6 = zchar
                                      if I32.eq(zchars_len, 7), do: z7 = zchar
                                      if I32.eq(zchars_len, 8), do: z8 = zchar
                                      zchars_len = I32.add(zchars_len, 1)
                                    end

                                    zchar = I32.add(k, 6)

                                    if I32.lt_u(
                                         zchars_len,
                                         if(I32.le_u(@version, 3),
                                           do: I32.const(6),
                                           else: I32.const(9)
                                         )
                                       ) do
                                      if I32.eq(zchars_len, 0), do: z0 = zchar
                                      if I32.eq(zchars_len, 1), do: z1 = zchar
                                      if I32.eq(zchars_len, 2), do: z2 = zchar
                                      if I32.eq(zchars_len, 3), do: z3 = zchar
                                      if I32.eq(zchars_len, 4), do: z4 = zchar
                                      if I32.eq(zchars_len, 5), do: z5 = zchar
                                      if I32.eq(zchars_len, 6), do: z6 = zchar
                                      if I32.eq(zchars_len, 7), do: z7 = zchar
                                      if I32.eq(zchars_len, 8), do: z8 = zchar
                                      zchars_len = I32.add(zchars_len, 1)
                                    end

                                    found = 1
                                    A2Search.break()
                                  end
                                end

                                k = I32.add(k, 1)
                                A2Loop.continue()
                              end
                            end
                          end
                        end

                        if I32.eq(found, 0) do
                          zchar = if(I32.le_u(@version, 2), do: I32.const(3), else: I32.const(5))

                          if I32.lt_u(
                               zchars_len,
                               if(I32.le_u(@version, 3), do: I32.const(6), else: I32.const(9))
                             ) do
                            if I32.eq(zchars_len, 0), do: z0 = zchar
                            if I32.eq(zchars_len, 1), do: z1 = zchar
                            if I32.eq(zchars_len, 2), do: z2 = zchar
                            if I32.eq(zchars_len, 3), do: z3 = zchar
                            if I32.eq(zchars_len, 4), do: z4 = zchar
                            if I32.eq(zchars_len, 5), do: z5 = zchar
                            if I32.eq(zchars_len, 6), do: z6 = zchar
                            if I32.eq(zchars_len, 7), do: z7 = zchar
                            if I32.eq(zchars_len, 8), do: z8 = zchar
                            zchars_len = I32.add(zchars_len, 1)
                          end

                          if I32.lt_u(
                               zchars_len,
                               if(I32.le_u(@version, 3), do: I32.const(6), else: I32.const(9))
                             ) do
                            if I32.eq(zchars_len, 0), do: z0 = 6
                            if I32.eq(zchars_len, 1), do: z1 = 6
                            if I32.eq(zchars_len, 2), do: z2 = 6
                            if I32.eq(zchars_len, 3), do: z3 = 6
                            if I32.eq(zchars_len, 4), do: z4 = 6
                            if I32.eq(zchars_len, 5), do: z5 = 6
                            if I32.eq(zchars_len, 6), do: z6 = 6
                            if I32.eq(zchars_len, 7), do: z7 = 6
                            if I32.eq(zchars_len, 8), do: z8 = 6
                            zchars_len = I32.add(zchars_len, 1)
                          end

                          if I32.lt_u(
                               zchars_len,
                               if(I32.le_u(@version, 3), do: I32.const(6), else: I32.const(9))
                             ) do
                            zchar = I32.band(I32.shr_u(char, 5), 0x1F)
                            if I32.eq(zchars_len, 0), do: z0 = zchar
                            if I32.eq(zchars_len, 1), do: z1 = zchar
                            if I32.eq(zchars_len, 2), do: z2 = zchar
                            if I32.eq(zchars_len, 3), do: z3 = zchar
                            if I32.eq(zchars_len, 4), do: z4 = zchar
                            if I32.eq(zchars_len, 5), do: z5 = zchar
                            if I32.eq(zchars_len, 6), do: z6 = zchar
                            if I32.eq(zchars_len, 7), do: z7 = zchar
                            if I32.eq(zchars_len, 8), do: z8 = zchar
                            zchars_len = I32.add(zchars_len, 1)
                          end

                          if I32.lt_u(
                               zchars_len,
                               if(I32.le_u(@version, 3), do: I32.const(6), else: I32.const(9))
                             ) do
                            zchar = I32.band(char, 0x1F)
                            if I32.eq(zchars_len, 0), do: z0 = zchar
                            if I32.eq(zchars_len, 1), do: z1 = zchar
                            if I32.eq(zchars_len, 2), do: z2 = zchar
                            if I32.eq(zchars_len, 3), do: z3 = zchar
                            if I32.eq(zchars_len, 4), do: z4 = zchar
                            if I32.eq(zchars_len, 5), do: z5 = zchar
                            if I32.eq(zchars_len, 6), do: z6 = zchar
                            if I32.eq(zchars_len, 7), do: z7 = zchar
                            if I32.eq(zchars_len, 8), do: z8 = zchar
                            zchars_len = I32.add(zchars_len, 1)
                          end
                        end

                        j = I32.add(j, 1)
                        EncodeLoop.continue()
                      end
                    end

                    w1 = I32.or(I32.shl(z0, 10), I32.or(I32.shl(z1, 5), z2))
                    w2 = I32.or(I32.shl(z3, 10), I32.or(I32.shl(z4, 5), z5))
                    w3 = 0

                    if I32.le_u(@version, 3) do
                      w2 = I32.or(w2, 0x8000)
                    else
                      w3 = I32.or(I32.shl(z6, 10), I32.or(I32.shl(z7, 5), z8))
                      w3 = I32.or(w3, 0x8000)
                    end

                    dict_addr = ldict(w1, w2, w3)
                    parse_idx = I32.add(p, I32.add(2, I32.mul(word_count, 4)))
                    write_word(parse_idx, dict_addr)
                    write_byte(I32.add(parse_idx, 2), word_len)

                    write_byte(
                      I32.add(parse_idx, 3),
                      I32.add(
                        word_start,
                        if(I32.ge_u(@version, 5), do: I32.const(2), else: I32.const(1))
                      )
                    )

                    word_count = I32.add(word_count, 1)
                  end

                  in_word = 0
                end

                if is_sep do
                  if I32.lt_u(word_count, max_words) do
                    char = read_byte(I32.add(text_start, i))

                    if I32.band(I32.ge_u(char, 65), I32.le_u(char, 90)) do
                      char = I32.add(char, 32)
                    end

                    z0 = if(I32.le_u(@version, 2), do: I32.const(3), else: I32.const(5))
                    k = 0
                    z1 = 5
                    alph_addr = 0x81034
                    if I32.ne(@version, 1) do
                      alph_addr = 0x8104E
                    end

                    loop SepFindLoop do
                      if I32.lt_u(k, 26) do
                        if I32.eq(read_byte(I32.add(alph_addr, k)), char) do
                          z1 = I32.add(k, 6)
                        else
                          k = I32.add(k, 1)
                          SepFindLoop.continue()
                        end
                      end
                    end

                    z2 = 5
                    z3 = 5
                    z4 = 5
                    z5 = 5
                    z6 = 5
                    z7 = 5
                    z8 = 5

                    w1 = I32.or(I32.shl(z0, 10), I32.or(I32.shl(z1, 5), z2))
                    w2 = I32.or(I32.shl(z3, 10), I32.or(I32.shl(z4, 5), z5))
                    w3 = 0

                    if I32.le_u(@version, 3) do
                      w2 = I32.or(w2, 0x8000)
                    else
                      w3 = I32.or(I32.shl(z6, 10), I32.or(I32.shl(z7, 5), z8))
                      w3 = I32.or(w3, 0x8000)
                    end

                    dict_addr = ldict(w1, w2, w3)
                    parse_idx = I32.add(p, I32.add(2, I32.mul(word_count, 4)))
                    write_word(parse_idx, dict_addr)
                    write_byte(I32.add(parse_idx, 2), 1)

                    write_byte(
                      I32.add(parse_idx, 3),
                      I32.add(i, if(I32.ge_u(@version, 5), do: I32.const(2), else: I32.const(1)))
                    )

                    word_count = I32.add(word_count, 1)
                  end
                end
              else
                if I32.eq(in_word, 0) do
                  word_start = i
                  word_len = 0
                  in_word = 1
                end

                word_len = I32.add(word_len, 1)
              end

              i = I32.add(i, 1)
              TokenLoop.continue()
            end
          end

          if in_word do
            if I32.lt_u(word_count, max_words) do
              z0 = 5
              z1 = 5
              z2 = 5
              z3 = 5
              z4 = 5
              z5 = 5
              z6 = 5
              z7 = 5
              z8 = 5
              zchars_len = 0
              j = 0

              loop EncodeLoop2 do
                if I32.band(
                     I32.lt_u(j, word_len),
                     I32.lt_u(zchars_len, if(I32.le_u(@version, 3), do: I32.const(6), else: I32.const(9)))
                   ) do
                  char = read_byte(I32.add(text_start, I32.add(word_start, j)))

                  if I32.band(I32.ge_u(char, 65), I32.le_u(char, 90)) do
                    char = I32.add(char, 32)
                  end

                  found = 0

                  if I32.eq(char, 32) do
                    if I32.lt_u(zchars_len, if(I32.le_u(@version, 3), do: I32.const(6), else: I32.const(9))) do
                      zchar = 0
                      if I32.eq(zchars_len, 0), do: z0 = zchar
                      if I32.eq(zchars_len, 1), do: z1 = zchar
                      if I32.eq(zchars_len, 2), do: z2 = zchar
                      if I32.eq(zchars_len, 3), do: z3 = zchar
                      if I32.eq(zchars_len, 4), do: z4 = zchar
                      if I32.eq(zchars_len, 5), do: z5 = zchar
                      if I32.eq(zchars_len, 6), do: z6 = zchar
                      if I32.eq(zchars_len, 7), do: z7 = zchar
                      if I32.eq(zchars_len, 8), do: z8 = zchar
                      zchars_len = I32.add(zchars_len, 1)
                    end

                    found = 1
                  end

                  if I32.band(I32.eq(found, 0), I32.band(I32.ge_u(char, 97), I32.le_u(char, 122))) do
                    zchar = I32.add(I32.sub(char, 97), 6)
                    if I32.lt_u(zchars_len, if(I32.le_u(@version, 3), do: I32.const(6), else: I32.const(9))) do
                      if I32.eq(zchars_len, 0), do: z0 = zchar
                      if I32.eq(zchars_len, 1), do: z1 = zchar
                      if I32.eq(zchars_len, 2), do: z2 = zchar
                      if I32.eq(zchars_len, 3), do: z3 = zchar
                      if I32.eq(zchars_len, 4), do: z4 = zchar
                      if I32.eq(zchars_len, 5), do: z5 = zchar
                      if I32.eq(zchars_len, 6), do: z6 = zchar
                      if I32.eq(zchars_len, 7), do: z7 = zchar
                      if I32.eq(zchars_len, 8), do: z8 = zchar
                      zchars_len = I32.add(zchars_len, 1)
                    end

                    found = 1
                  end

                  if I32.eq(found, 0) do
                    k = 0

                    Control.block A1Search2 do
                      loop A1Loop2 do
                        if I32.lt_u(k, 26) do
                          if I32.eq(read_byte(I32.add(0x8101A, k)), char) do
                            zchar = if(I32.le_u(@version, 2), do: I32.const(2), else: I32.const(4))

                            if I32.lt_u(zchars_len, if(I32.le_u(@version, 3), do: I32.const(6), else: I32.const(9))) do
                              if I32.eq(zchars_len, 0), do: z0 = zchar
                              if I32.eq(zchars_len, 1), do: z1 = zchar
                              if I32.eq(zchars_len, 2), do: z2 = zchar
                              if I32.eq(zchars_len, 3), do: z3 = zchar
                              if I32.eq(zchars_len, 4), do: z4 = zchar
                              if I32.eq(zchars_len, 5), do: z5 = zchar
                              if I32.eq(zchars_len, 6), do: z6 = zchar
                              if I32.eq(zchars_len, 7), do: z7 = zchar
                              if I32.eq(zchars_len, 8), do: z8 = zchar
                              zchars_len = I32.add(zchars_len, 1)
                            end

                            zchar = I32.add(k, 6)

                            if I32.lt_u(zchars_len, if(I32.le_u(@version, 3), do: I32.const(6), else: I32.const(9))) do
                              if I32.eq(zchars_len, 0), do: z0 = zchar
                              if I32.eq(zchars_len, 1), do: z1 = zchar
                              if I32.eq(zchars_len, 2), do: z2 = zchar
                              if I32.eq(zchars_len, 3), do: z3 = zchar
                              if I32.eq(zchars_len, 4), do: z4 = zchar
                              if I32.eq(zchars_len, 5), do: z5 = zchar
                              if I32.eq(zchars_len, 6), do: z6 = zchar
                              if I32.eq(zchars_len, 7), do: z7 = zchar
                              if I32.eq(zchars_len, 8), do: z8 = zchar
                              zchars_len = I32.add(zchars_len, 1)
                            end

                            found = 1
                            A1Search2.break()
                          end

                          k = I32.add(k, 1)
                          A1Loop2.continue()
                        end
                      end
                    end
                  end

                  if I32.eq(found, 0) do
                    alph_addr = 0x81034
                    if I32.ne(@version, 1) do
                      alph_addr = 0x8104E
                    end

                    k = 0

                    Control.block A2Search2 do
                      loop A2Loop2 do
                        if I32.lt_u(k, 26) do
                          if I32.eq(read_byte(I32.add(alph_addr, k)), char) do
                            if I32.ne(k, 0) do
                              zchar = if(I32.le_u(@version, 2), do: I32.const(3), else: I32.const(5))

                              if I32.lt_u(zchars_len, if(I32.le_u(@version, 3), do: I32.const(6), else: I32.const(9))) do
                                if I32.eq(zchars_len, 0), do: z0 = zchar
                                if I32.eq(zchars_len, 1), do: z1 = zchar
                                if I32.eq(zchars_len, 2), do: z2 = zchar
                                if I32.eq(zchars_len, 3), do: z3 = zchar
                                if I32.eq(zchars_len, 4), do: z4 = zchar
                                if I32.eq(zchars_len, 5), do: z5 = zchar
                                if I32.eq(zchars_len, 6), do: z6 = zchar
                                if I32.eq(zchars_len, 7), do: z7 = zchar
                                if I32.eq(zchars_len, 8), do: z8 = zchar
                                zchars_len = I32.add(zchars_len, 1)
                              end

                              zchar = I32.add(k, 6)

                              if I32.lt_u(zchars_len, if(I32.le_u(@version, 3), do: I32.const(6), else: I32.const(9))) do
                                if I32.eq(zchars_len, 0), do: z0 = zchar
                                if I32.eq(zchars_len, 1), do: z1 = zchar
                                if I32.eq(zchars_len, 2), do: z2 = zchar
                                if I32.eq(zchars_len, 3), do: z3 = zchar
                                if I32.eq(zchars_len, 4), do: z4 = zchar
                                if I32.eq(zchars_len, 5), do: z5 = zchar
                                if I32.eq(zchars_len, 6), do: z6 = zchar
                                if I32.eq(zchars_len, 7), do: z7 = zchar
                                if I32.eq(zchars_len, 8), do: z8 = zchar
                                zchars_len = I32.add(zchars_len, 1)
                              end

                              found = 1
                              A2Search2.break()
                            end
                          end

                          k = I32.add(k, 1)
                          A2Loop2.continue()
                        end
                      end
                    end
                  end

                  if I32.eq(found, 0) do
                    zchar = if(I32.le_u(@version, 2), do: I32.const(3), else: I32.const(5))

                    if I32.lt_u(zchars_len, if(I32.le_u(@version, 3), do: I32.const(6), else: I32.const(9))) do
                      if I32.eq(zchars_len, 0), do: z0 = zchar
                      if I32.eq(zchars_len, 1), do: z1 = zchar
                      if I32.eq(zchars_len, 2), do: z2 = zchar
                      if I32.eq(zchars_len, 3), do: z3 = zchar
                      if I32.eq(zchars_len, 4), do: z4 = zchar
                      if I32.eq(zchars_len, 5), do: z5 = zchar
                      if I32.eq(zchars_len, 6), do: z6 = zchar
                      if I32.eq(zchars_len, 7), do: z7 = zchar
                      if I32.eq(zchars_len, 8), do: z8 = zchar
                      zchars_len = I32.add(zchars_len, 1)
                    end

                    if I32.lt_u(zchars_len, if(I32.le_u(@version, 3), do: I32.const(6), else: I32.const(9))) do
                      if I32.eq(zchars_len, 0), do: z0 = 6
                      if I32.eq(zchars_len, 1), do: z1 = 6
                      if I32.eq(zchars_len, 2), do: z2 = 6
                      if I32.eq(zchars_len, 3), do: z3 = 6
                      if I32.eq(zchars_len, 4), do: z4 = 6
                      if I32.eq(zchars_len, 5), do: z5 = 6
                      if I32.eq(zchars_len, 6), do: z6 = 6
                      if I32.eq(zchars_len, 7), do: z7 = 6
                      if I32.eq(zchars_len, 8), do: z8 = 6
                      zchars_len = I32.add(zchars_len, 1)
                    end

                    if I32.lt_u(zchars_len, if(I32.le_u(@version, 3), do: I32.const(6), else: I32.const(9))) do
                      zchar = I32.band(I32.shr_u(char, 5), 0x1F)
                      if I32.eq(zchars_len, 0), do: z0 = zchar
                      if I32.eq(zchars_len, 1), do: z1 = zchar
                      if I32.eq(zchars_len, 2), do: z2 = zchar
                      if I32.eq(zchars_len, 3), do: z3 = zchar
                      if I32.eq(zchars_len, 4), do: z4 = zchar
                      if I32.eq(zchars_len, 5), do: z5 = zchar
                      if I32.eq(zchars_len, 6), do: z6 = zchar
                      if I32.eq(zchars_len, 7), do: z7 = zchar
                      if I32.eq(zchars_len, 8), do: z8 = zchar
                      zchars_len = I32.add(zchars_len, 1)
                    end

                    if I32.lt_u(zchars_len, if(I32.le_u(@version, 3), do: I32.const(6), else: I32.const(9))) do
                      zchar = I32.band(char, 0x1F)
                      if I32.eq(zchars_len, 0), do: z0 = zchar
                      if I32.eq(zchars_len, 1), do: z1 = zchar
                      if I32.eq(zchars_len, 2), do: z2 = zchar
                      if I32.eq(zchars_len, 3), do: z3 = zchar
                      if I32.eq(zchars_len, 4), do: z4 = zchar
                      if I32.eq(zchars_len, 5), do: z5 = zchar
                      if I32.eq(zchars_len, 6), do: z6 = zchar
                      if I32.eq(zchars_len, 7), do: z7 = zchar
                      if I32.eq(zchars_len, 8), do: z8 = zchar
                      zchars_len = I32.add(zchars_len, 1)
                    end
                  end

                  j = I32.add(j, 1)
                  EncodeLoop2.continue()
                end
              end

              w1 = I32.or(I32.shl(z0, 10), I32.or(I32.shl(z1, 5), z2))
              w2 = I32.or(I32.shl(z3, 10), I32.or(I32.shl(z4, 5), z5))
              w3 = 0

              if I32.le_u(@version, 3) do
                w2 = I32.or(w2, 0x8000)
              else
                w3 = I32.or(I32.shl(z6, 10), I32.or(I32.shl(z7, 5), z8))
                w3 = I32.or(w3, 0x8000)
              end

              dict_addr = ldict(w1, w2, w3)
              parse_idx = I32.add(p, I32.add(2, I32.mul(word_count, 4)))
              write_word(parse_idx, dict_addr)
              write_byte(I32.add(parse_idx, 2), word_len)

              write_byte(
                I32.add(parse_idx, 3),
                I32.add(
                  word_start,
                  if(I32.ge_u(@version, 5), do: I32.const(2), else: I32.const(1))
                )
              )

              word_count = I32.add(word_count, 1)
            end
          end

          write_byte(I32.add(p, 1), word_count)

          # Clear remaining parse buffer slots
          write_word(I32.add(I32.add(p, 2), I32.mul(word_count, 4)), 0)
          write_word(I32.add(I32.add(p, 4), I32.mul(word_count, 4)), 0)
          write_word(I32.add(I32.add(p, 6), I32.mul(word_count, 4)), 0)
          write_word(I32.add(I32.add(p, 8), I32.mul(word_count, 4)), 0)
          write_word(I32.add(I32.add(p, 10), I32.mul(word_count, 4)), 0)
          write_word(I32.add(I32.add(p, 12), I32.mul(word_count, 4)), 0)
          write_word(I32.add(I32.add(p, 14), I32.mul(word_count, 4)), 0)
          write_word(I32.add(I32.add(p, 16), I32.mul(word_count, 4)), 0)
          write_word(I32.add(I32.add(p, 18), I32.mul(word_count, 4)), 0)
          write_word(I32.add(I32.add(p, 20), I32.mul(word_count, 4)), 0)
          write_word(I32.add(I32.add(p, 22), I32.mul(word_count, 4)), 0)
          write_word(I32.add(I32.add(p, 24), I32.mul(word_count, 4)), 0)
          write_word(I32.add(I32.add(p, 26), I32.mul(word_count, 4)), 0)
          write_word(I32.add(I32.add(p, 28), I32.mul(word_count, 4)), 0)
          write_word(I32.add(I32.add(p, 30), I32.mul(word_count, 4)), 0)
          write_word(I32.add(I32.add(p, 32), I32.mul(word_count, 4)), 0)
        end
      end

    # 4. Transform AST in a single pass
    final_ast =
      Macro.prewalk(ast, fn
        {:defmodule, meta, children} = node ->
          if is_list(children) do
            [_old_name, args_list | _] = children
            body = case args_list do
              [{{:__block__, _, [:do]}, b}] -> b
              _ -> Keyword.get(args_list, :do)
            end

            if is_nil(body) do
              node
            else
              alias_node = {:__aliases__, [alias: false], Module.split(module_name) |> Enum.map(&String.to_atom/1)}
              list_children = case body do
                {:__block__, _, list} -> list
                item -> [item]
              end

              processed_children = list_children
                |> Enum.reject(fn
                  {{:., _, [target, func]}, _, _} when func in [:pages, :initial_data!] ->
                    target_str = Macro.to_string(target)
                    target_str == "Memory" or target_str == "Orb.Memory"
                  _ -> false
                end)
                |> Enum.map(fn
                  {:global, _, _} -> global_block_ast
                  {:defw, _, [name_node | _]} = node ->
                    name = case name_node do
                      {name, _, _} when is_atom(name) -> name
                      name when is_atom(name) -> name
                      _ -> nil
                    end
                    case name do
                      :ldict -> ldict_definition_ast
                      :mdict -> mdict_definition_ast
                      :do_tokenise -> do_tokenise_definition_ast
                      _ -> node
                    end
                  node -> node
                end)

              final_children = inject_after_use_orb(processed_children, {:__block__, [], [host_registration_ast | memory_setup_ast]})
                |> Enum.reject(&is_nil/1)

              {:defmodule, meta, [alias_node, [do: {:__block__, [], final_children}]]}
            end
          else
            node
          end
        node -> node
      end)

    source_code = Sourceror.to_string(final_ast)
    File.write!("tmp/last_bespoke_source.ex", source_code)

    data = %{
      bespoke_story_data: pruned_story,
      bespoke_unicode_bin: unicode,
      bespoke_alphabets_bin: alphabets,
      bespoke_hash_table_bin: hash_table
    }

    {source_code, data}
  end

  defp chunk_initial_data(base_offset, bin) do
    chunk_size = 512
    bin |> byte_size() |> then(fn size ->
      if size == 0 do
        []
      else
        for offset <- 0..(size - 1) |> Enum.take_every(chunk_size) do
          len = min(chunk_size, size - offset)
          chunk = binary_part(bin, offset, len)
          bytes = :binary.bin_to_list(chunk)
          quote do: Orb.Memory.initial_data!(unquote(base_offset + offset), u8: unquote(bytes))
        end
      end
    end)
  end

  def prune_version_branches(ast, version) do
    Macro.prewalk(ast, fn
      {:defw, meta, args} ->
        new_args = Enum.map(args, fn
          [do: body] -> [do: prune_version_branches_in_block(body, version)]
          other -> other
        end)
        {:defw, meta, new_args}
      {:if, _, _} = node -> prune_version_branches_in_block(node, version)
      node -> node
    end)
  end

  defp prune_version_branches_in_block(nil, _version), do: quote(do: Orb.DSL.nop())
  defp prune_version_branches_in_block(body, version) do
    Macro.prewalk(body, fn
      nil -> quote(do: Orb.DSL.nop())
      {:if, meta, [condition, blocks]} ->
        case condition do
          {{:., _, [target, op]}, _, [{:@, _, [{v_name, _, _}]}, v]}
          when op in [:ge_u, :le_u, :lt_u, :gt_u, :eq, :ne] and v_name == :version ->
            target_str = Macro.to_string(target)
            if target_str in ["I32", "Orb.I32"] do
              yes = blocks[:do] || quote(do: Orb.DSL.nop())
              no = blocks[:else] || quote(do: Orb.DSL.nop())
              take_yes = case op do
                :ge_u -> version >= v
                :le_u -> version <= v
                :lt_u -> version < v
                :gt_u -> version > v
                :eq -> version == v
                :ne -> version != v
              end
              if take_yes, do: yes, else: no
            else
              {:if, meta, [condition, blocks]}
            end
          _ -> {:if, meta, [condition, blocks]}
        end
      node -> node
    end)
  end

  defp inject_after_use_orb(children, new_setup) do
    index = Enum.find_index(children, fn
      {:use, _, [{:__aliases__, _, [:Orb]}]} -> true
      _ -> false
    end)
    setup_children = case new_setup do
      {:__block__, _, list} -> list
      item -> [item]
    end
    case index do
      nil -> setup_children ++ children
      i ->
        {head, tail} = Enum.split(children, i + 1)
        head ++ setup_children ++ tail
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
      do: (<<_::320, r::16, s::16, _::binary>> = story_data; {r * 8, s * 8}),
      else: {0, 0}
  end

  def prune_story_data(data, _opts), do: data

  def generate_dictionary_hash_table(story_data, dict_base, version) do
    <<_::binary-size(dict_base), num_sep::8, _::binary>> = story_data
    header_end = dict_base + 1 + num_sep
    <<_::binary-size(header_end), entry_len::8, num_entries::16, _::binary>> = story_data
    entries_start = header_end + 3
    table_size = 2048
    mask = table_size - 1
    table = Tuple.duplicate({0, 0, 0, 0}, table_size)
    final_table = if num_entries > 0 do
      Enum.reduce(0..(num_entries - 1), table, fn i, acc ->
        addr = entries_start + i * entry_len
        {w1, w2, w3} = get_encoded_words(story_data, addr, version)
        hash = Bitwise.bxor(w1, Bitwise.bxor(w2, w3)) |> Bitwise.band(mask)
        insert_at_slot(acc, hash, w1, w2, w3, addr, mask)
      end)
    else
      table
    end
    bin = for i <- 0..(table_size - 1), into: <<>> do
      {w1, w2, w3, addr} = elem(final_table, i)
      combined1 = Bitwise.bor(Bitwise.bsl(w1, 16), w2)
      <<combined1::32-little, w3::32-little, 0::32-little, addr::32-little>>
    end
    {bin, mask}
  end

  defp get_encoded_words(story_data, addr, version) do
    if version <= 3 do
      <<_::binary-size(addr), w1::16-big, w2::16-big, _::binary>> = story_data
      {w1, w2, 0}
    else
      <<_::binary-size(addr), w1::16-big, w2::16-big, w3::16-big, _::binary>> = story_data
      {w1, w2, w3}
    end
  end

  defp insert_at_slot(table, slot, w1, w2, w3, addr, mask) do
    case elem(table, slot) do
      {0, 0, 0, 0} -> put_elem(table, slot, {w1, w2, w3, addr})
      _ -> insert_at_slot(table, Bitwise.band(slot + 1, mask), w1, w2, w3, addr, mask)
    end
  end

  def generate_unicode_binary do
    table = [0x00E4, 0x00F6, 0x00FC, 0x00C4, 0x00D6, 0x00DC, 0x00DF, 0x00BB, 0x00AB, 0x00EB, 0x00EF, 0x00FF, 0x00CB, 0x00CF, 0x00E1, 0x00E9, 0x00ED, 0x00F3, 0x00FA, 0x00FD, 0x00C1, 0x00C9, 0x00CD, 0x00D3, 0x00DA, 0x00DD, 0x00E0, 0x00E8, 0x00EC, 0x00F2, 0x00F9, 0x00C0, 0x00C8, 0x00CC, 0x00D2, 0x00D9, 0x00E2, 0x00EA, 0x00EE, 0x00F4, 0x00FB, 0x00C2, 0x00CA, 0x00CE, 0x00D4, 0x00DB, 0x00E5, 0x00C5, 0x00F8, 0x00D8, 0x00E3, 0x00F1, 0x00F5, 0x00C3, 0x00D1, 0x00D5, 0x00E6, 0x00C6, 0x00E7, 0x00C7, 0x00FE, 0x00F0, 0x00DE, 0x00D0, 0x00A3, 0x0153, 0x0152, 0x00A1, 0x00BF, 0x00AA, 0x00BA, 0x00E6, 0x00C6, 0x00F8, 0x00D8, 0x00E5, 0x00C5, 0x00E7, 0x00C7, 0x00F0, 0x00D0, 0x00F1, 0x00D1, 0x00F5, 0x00D5, 0x00FE, 0x00DE, 0x00A9, 2122, 0x20AC, 0x0024, 0x0192, 0x03B1, 0x03B2, 0x03B3, 0x03B4, 0x03B5, 0x03B6, 0x03B7, 0x03B8, 0x03B9, 0x03BA, 0x03BB, 0x03BC, 0x03BD, 0x03BE, 0x03BF, 0x03C0, 0x03C1, 0x03C2, 0x03C3, 0x03C4, 0x03C5, 0x03C6, 0x03C7, 0x03C8, 0x03C9, 0x0391, 0x0392, 0x0393, 0x0394, 0x0395, 0x0396, 0x0397, 0x0398, 0x0399, 0x039A, 0x039B, 0x039C, 0x039D, 0x039E, 0x039F, 0x03A0, 0x03A1, 0x03A3, 0x03A4, 0x03A5, 0x03A6, 0x03A7, 0x03A8, 0x03A9]
    for u <- table, into: <<>>, do: <<u::16-big>>
  end
end
