defmodule Zorb.Interpreter.Logic do
  @moduledoc """
  Core Z-machine implementation logic for optimized Game Capsules.
  """

  @doc """
  Generates the complete Elixir source code for a bespoke Game Capsule module.
  """
  def generate_module_source(module_name, story_data) do
    IO.puts(:stderr, "Zorb: Logic.generate_module_source for #{module_name}")

    logic_path = Path.join(Path.join(File.cwd!(), "lib/zorb/interpreter"), "logic_body.exs")

    template_path =
      Path.join(Path.join(File.cwd!(), "lib/zorb/interpreter"), "logic_template.exs")

    logic_body_content = File.read!(logic_path)
    template_content = File.read!(template_path)

    # Transform logic body to handle locals and qualification
    logic_body_ast = transform_logic_body(logic_body_content)

    # Extract header fields
    <<
      v::8,
      _::8,
      _base_pc::16,
      dictionary_base::16,
      object_table_base::16,
      globals_base::16,
      static_memory_base::16,
      # flags
      _::16,
      # serial
      _::16,
      abbreviations_base::16,
      _rest::binary
    >> = story_data

    # Version-specific calculations
    {pas_init, oes_init, po_init, soj_init, co_init, pto_init} =
      case v <= 3 do
        true -> {1, 9, 4, 5, 6, 7}
        false -> {2, 14, 6, 8, 10, 12}
      end

    {ro_init, so_init} =
      case v do
        v when v in 6..7 ->
          <<_::160, r_off::16, s_off::16, _::binary>> = story_data
          {r_off * 8, s_off * 8}

        _ ->
          {0, 0}
      end

    unicode_table = [
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

    unicode_bin = Enum.map_join(unicode_table, fn u -> <<u::16-big>> end)

    alphabets =
      "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ 0123456789.,!?_#'\"/\\<-:() \r0123456789.,!?_#'\"/\\-:()"

    # Prepare imports as a literal list
    import_list = Zorb.Capsule.Host.__wasm_imports__(nil)

    import_registrations =
      Enum.map_join(import_list, "\n  ", fn imp ->
        "@wasm_imports #{inspect(imp)}"
      end)

    source =
      template_content
      |> String.replace("MOD_NAME", inspect(module_name))
      |> String.replace("V_INIT", "#{v}")
      |> String.replace("SB_INIT", "#{static_memory_base}")
      |> String.replace("GB_INIT", "#{globals_base}")
      |> String.replace("DB_INIT", "#{dictionary_base}")
      |> String.replace("OB_INIT", "#{object_table_base}")
      |> String.replace("AB_INIT", "#{abbreviations_base}")
      |> String.replace("PAS_INIT", "#{pas_init}")
      |> String.replace("RO_INIT", "#{ro_init}")
      |> String.replace("SO_INIT", "#{so_init}")
      |> String.replace("OES_INIT", "#{oes_init}")
      |> String.replace("PO_INIT", "#{po_init}")
      |> String.replace("SOJ_INIT", "#{soj_init}")
      |> String.replace("CO_INIT", "#{co_init}")
      |> String.replace("PTO_INIT", "#{pto_init}")
      |> String.replace("UTB_INIT", "#{0x80000}")
      |> String.replace("STORY_LEN", "#{byte_size(story_data)}")
      |> String.replace("STORY_DATA", inspect(story_data, limit: :infinity))
      |> String.replace("UNICODE_DATA", inspect(unicode_bin, limit: :infinity))
      |> String.replace("ALPHABETS_DATA", inspect(alphabets, limit: :infinity))
      |> String.replace("LOGIC_BODY", Macro.to_string(logic_body_ast))
      |> String.replace("Orb.Import.register(Zorb.Capsule.Host)", import_registrations)

    File.write!("tmp/last_bespoke_module.ex", source)
    source
  end

  defp transform_logic_body(content) do
    ast = Sourceror.parse_string!(content)

    # Helper to recursively find all atoms in any nested structure
    get_all_atoms = fn node ->
      {_, atoms} =
        Macro.prewalk(node, MapSet.new(), fn
          # Leaf atom
          n, acc when is_atom(n) ->
            {n, MapSet.put(acc, n)}

          # Look inside tuples {a, b, c} - common in AST
          tuple, acc when is_tuple(tuple) ->
            # Add any atom elements of the tuple
            new_acc =
              Enum.reduce(Tuple.to_list(tuple), acc, fn
                item, i_acc when is_atom(item) -> MapSet.put(i_acc, item)
                _, i_acc -> i_acc
              end)

            {tuple, new_acc}

          node, acc ->
            {node, acc}
        end)

      atoms
    end

    # 1. Map out all function names
    ast_list =
      case ast do
        {:__block__, _, list} -> list
        other -> [other]
      end

    defined_funcs =
      MapSet.new(
        Enum.flat_map(ast_list, fn
          {def_macro, _, [{name, _, _} | _]} when def_macro in [:def_macro, :defw, :defwp] ->
            [name]

          _ ->
            []
        end)
      )

    # 2. Extract break_if_halted body for inlining
    break_if_halted_body =
      Enum.find_value(ast_list, fn
        {:defwp, _, [{:break_if_halted, _, _}, [do: body]]} -> body
        _ -> nil
      end)

    # 3. Process functions
    locals =
      ~w(v1 v2 v3 v4 val addr byte target arg_count i num_locals old_fp ret_pc result_info parent child curr prev len header data_addr byte_addr num char stream local_val actual expected entry_len dict sum table_entry type types word is_word j old old_alpha old_pc op opc sib size)a

    new_ast_list =
      Enum.reject(ast_list, fn
        {:defwp, _, [{:break_if_halted, _, _}, _]} -> true
        _ -> false
      end)
      |> Enum.map(fn
        {def_macro, meta, [head | rest]} when def_macro in [:defw, :defwp] ->
          # Change all defwp to defw to allow qualified local calls
          def_macro = :defw

          # Strip export: true from head if present
          new_head =
            case head do
              {name, hmeta, hargs} when is_list(hargs) ->
                new_hargs =
                  Enum.map(hargs, fn
                    kw when is_list(kw) ->
                      Enum.reject(kw, fn
                        {:export, _} -> true
                        {{:__block__, _, [:export]}, _} -> true
                        _ -> false
                      end)

                    other ->
                      other
                  end)
                  |> Enum.reject(fn x -> x == [] end)

                {name, hmeta, new_hargs}

              _ ->
                head
            end

          func_args = MapSet.new(extract_args(new_head))

          # Transformation with state for loops
          {transformed_rest, _} =
            Macro.traverse(
              rest,
              %{stack: [], counter: 0},
              # pre
              fn
                {:break_if_halted, _, _}, state ->
                  {break_if_halted_body, state}

                {:loop, l_meta, args} = node, state ->
                  # Check for anonymous loop [do: block] or [{{:__block__, _, [:do]}, block}]
                  is_anon =
                    case args do
                      [[do: _]] -> true
                      [[{{:__block__, _, [:do]}, _}]] -> true
                      _ -> false
                    end

                  if is_anon do
                    block =
                      case args do
                        [[do: b]] -> b
                        [[{_, b}]] -> b
                      end

                    id = state.counter + 1
                    label = :"L#{id}"
                    exit_label = :"ExitL#{id}"
                    new_node = {:__loop_wrapped__, l_meta, [label, exit_label, block]}
                    {new_node, %{state | counter: id, stack: [exit_label | state.stack]}}
                  else
                    {node, state}
                  end

                {:break, b_meta, args}, state ->
                  exit_label = List.first(state.stack)
                  new_node = {:__break_wrapped__, b_meta, [exit_label, args]}
                  {new_node, state}

                {:case, c_meta, args}, state ->
                  val = List.first(args)
                  blocks = List.last(args)

                  clauses =
                    case blocks do
                      [do: cs] ->
                        cs

                      [{{:__block__, _, [:do]}, cs}] ->
                        cs

                      kw when is_list(kw) ->
                        kw[:do]

                      _ ->
                        if is_list(blocks) do
                          Enum.find_value(blocks, fn
                            {:do, cs} -> cs
                            {{:__block__, _, [:do]}, cs} -> cs
                            _ -> nil
                          end)
                        else
                          nil
                        end
                    end

                  if clauses do
                    new_node = transform_case_to_if_chain(val, clauses)
                    {new_node, state}
                  else
                    {{:case, c_meta, args}, state}
                  end

                {:return, r_meta, args}, state ->
                  # Fix return/1 qualification
                  new_node =
                    case args do
                      [] ->
                        {{:., r_meta,
                          [{:__aliases__, [alias: false], [:Orb, :Control]}, :return]}, r_meta,
                         []}

                      _ ->
                        {{:., r_meta, [{:__aliases__, [alias: false], [:Orb, :DSL]}, :return]},
                         r_meta, args}
                    end

                  {new_node, state}

                {{:., r_meta, [{:__aliases__, ameta, [:Orb, :Control]}, :return]}, r_meta2, args},
                state ->
                  new_node =
                    case args do
                      [] ->
                        {{:., r_meta, [{:__aliases__, ameta, [:Orb, :Control]}, :return]},
                         r_meta2, []}

                      _ ->
                        {{:., r_meta, [{:__aliases__, ameta, [:Orb, :DSL]}, :return]}, r_meta2,
                         args}
                    end

                  {new_node, state}

                {name, f_meta, f_args}, state
                when is_atom(name) and
                       name not in [
                         :if,
                         :loop,
                         :break,
                         :continue,
                         :break_if,
                         :v_at_least,
                         :__loop_wrapped__,
                         :__break_wrapped__
                       ] ->
                  if MapSet.member?(defined_funcs, name) do
                    new_node =
                      {{:., f_meta, [{:__aliases__, [alias: false], [:__MODULE__]}, name]},
                       f_meta, f_args || []}

                    {new_node, state}
                  else
                    {{name, f_meta, f_args}, state}
                  end

                nil, state ->
                  # Transform nil to nop() inside function bodies
                  new_node =
                    {{:., [], [{:__aliases__, [alias: false], [:Orb, :DSL]}, :nop]}, [], []}

                  {new_node, state}

                node, state ->
                  {node, state}
              end,
              # post
              fn
                {:__loop_wrapped__, _l_meta, [label, exit_label, block]}, state ->
                  new_node =
                    quote do
                      Orb.Control.block unquote(exit_label) do
                        Orb.DSL.loop unquote(label) do
                          unquote(block)
                        end
                      end
                    end

                  {_, new_stack} = List.pop_at(state.stack, 0)
                  {new_node, %{state | stack: new_stack}}

                {:__break_wrapped__, b_meta, [exit_label, args]}, state ->
                  new_args =
                    case args do
                      [] -> [exit_label]
                      [{:if, _, [cond]}] -> [exit_label, [if: cond]]
                      [[if: cond]] -> [exit_label, [if: cond]]
                      _ -> [exit_label | args]
                    end

                  new_node =
                    {{:., b_meta, [{:__aliases__, [alias: false], [:Orb, :Control]}, :break]},
                     b_meta, new_args}

                  {new_node, state}

                node, state ->
                  {node, state}
              end
            )

          used_locals =
            get_all_atoms.(transformed_rest)
            |> MapSet.new()
            |> MapSet.intersection(MapSet.new(locals))
            |> MapSet.difference(func_args)
            |> MapSet.difference(defined_funcs)

          locals_list =
            Enum.map(Enum.sort(used_locals), fn name ->
              {name, {:__aliases__, [alias: false], [:Orb, :I32]}}
            end)

          new_args =
            if locals_list == [] do
              [new_head | transformed_rest]
            else
              case Enum.split(transformed_rest, -1) do
                {prefix, [body]} -> [new_head | prefix] ++ [locals_list, body]
                _ -> [new_head | transformed_rest]
              end
            end

          {def_macro, meta, new_args}

        node ->
          node
      end)

    {:__block__, [], new_ast_list}
  end

  defp transform_case_to_if_chain(val, clauses) do
    Enum.reduce(Enum.reverse(clauses), nil, fn
      {:->, meta, [ps, body]}, acc ->
        # body can be nil or a block
        body =
          if is_nil(body),
            do: {{:., [], [{:__aliases__, [alias: false], [:Orb, :DSL]}, :nop]}, [], []},
            else: body

        cond_node =
          case ps do
            [{:_, _, _}] ->
              :catch_all

            [p] ->
              {{:., meta, [{:__aliases__, [alias: false], [:Orb, :I32]}, :eq]}, meta, [val, p]}

            ps_list ->
              Enum.reduce(ps_list, nil, fn p, iacc ->
                eq =
                  {{:., meta, [{:__aliases__, [alias: false], [:Orb, :I32]}, :eq]}, meta,
                   [val, p]}

                if iacc do
                  {{:., meta, [{:__aliases__, [alias: false], [:Orb, :I32]}, :or]}, meta,
                   [iacc, eq]}
                else
                  eq
                end
              end)
          end

        if cond_node == :catch_all do
          body
        else
          if acc do
            {:if, meta, [cond_node, [do: body, else: acc]]}
          else
            {:if, meta, [cond_node, [do: body]]}
          end
        end

      _, acc ->
        acc
    end)
  end

  defp extract_args({_name, _meta, args}) when is_list(args) do
    Enum.flat_map(args, fn
      list when is_list(list) ->
        Enum.map(list, fn
          {{:__block__, _, [name]}, _type} when is_atom(name) -> name
          {name, _type} when is_atom(name) -> name
          _ -> nil
        end)
        |> Enum.reject(&is_nil/1)

      {name, _, nil} when is_atom(name) ->
        [name]

      {:__block__, _, [name]} when is_atom(name) ->
        [name]

      _ ->
        []
    end)
  end

  defp extract_args(_), do: []
end
