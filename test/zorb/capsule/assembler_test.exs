defmodule Zorb.Capsule.AssemblerTest do
  use ExUnit.Case, async: true
  alias Zorb.Capsule.Assembler

  describe "prune_version_branches/2" do
    test "prunes ge_u branch when version is too low" do
      ast =
        quote do
          defw test() do
            if Orb.I32.ge_u(@version, 5) do
              yes_branch()
            else
              no_branch()
            end
          end
        end

      pruned = Assembler.prune_version_branches(ast, 3)
      assert Macro.to_string(pruned) =~ "no_branch()"
      refute Macro.to_string(pruned) =~ "yes_branch()"
    end

    test "keeps ge_u branch when version is high enough" do
      ast =
        quote do
          defw test() do
            if Orb.I32.ge_u(@version, 5) do
              yes_branch()
            else
              no_branch()
            end
          end
        end

      pruned = Assembler.prune_version_branches(ast, 5)
      assert Macro.to_string(pruned) =~ "yes_branch()"
      refute Macro.to_string(pruned) =~ "no_branch()"
    end

    test "handles missing else branch" do
      ast =
        quote do
          defw test() do
            if Orb.I32.ge_u(@version, 5) do
              yes_branch()
            end
          end
        end

      pruned = Assembler.prune_version_branches(ast, 3)
      # Should have empty body when branch is not taken
      refute Macro.to_string(pruned) =~ "yes_branch()"
    end

    test "prunes le_u branch" do
      ast =
        quote do
          defw test() do
            if Orb.I32.le_u(@version, 3) do
              v3_logic()
            else
              modern_logic()
            end
          end
        end

      pruned_v3 = Assembler.prune_version_branches(ast, 3)
      assert Macro.to_string(pruned_v3) =~ "v3_logic()"
      refute Macro.to_string(pruned_v3) =~ "modern_logic()"

      pruned_v5 = Assembler.prune_version_branches(ast, 5)
      assert Macro.to_string(pruned_v5) =~ "modern_logic()"
      refute Macro.to_string(pruned_v5) =~ "v3_logic()"
    end

    test "prunes eq branch" do
      ast =
        quote do
          defw test() do
            if Orb.I32.eq(@version, 1) do
              v1_only()
            end
          end
        end

      pruned_v1 = Assembler.prune_version_branches(ast, 1)
      assert Macro.to_string(pruned_v1) =~ "v1_only()"

      pruned_v3 = Assembler.prune_version_branches(ast, 3)
      refute Macro.to_string(pruned_v3) =~ "v1_only()"
    end

    test "handles complex nested blocks" do
      ast =
        quote do
          defw test() do
            if Orb.I32.ge_u(@version, 5) do
              modern()
            else
              legacy()
            end

            always_runs()
          end
        end

      pruned = Assembler.prune_version_branches(ast, 5)

      expected =
        quote do
          defw test() do
            modern()
            always_runs()
          end
        end

      assert Macro.to_string(pruned) == Macro.to_string(expected)
    end

    test "handles empty blocks" do
      ast =
        quote do
          defw test() do
            {:__block__, [], []}
          end
        end

      pruned = Assembler.prune_version_branches(ast, 5)

      expected =
        quote do
          defw test() do
            {:__block__, [], []}
          end
        end

      assert Macro.to_string(pruned) == Macro.to_string(expected)
    end
  end

  describe "generate_dictionary_hash_table/3" do
    test "generates a valid hash table from minimal story data" do
      # Minimal V3 dictionary at 0x10
      dict_base = 0x10
      num_sep = 1
      entry_len = 7
      num_entries = 2

      # Construction
      padding = <<0::size(dict_base)-unit(8)>>
      header = <<num_sep, ?., entry_len, num_entries::16>>
      entry1 = <<0x11, 0x22, 0x33, 0x44, 0, 0, 0>>
      entry2 = <<0x55, 0x66, 0x77, 0x88, 0, 0, 0>>

      story_data = padding <> header <> entry1 <> entry2

      {bin, mask} = Assembler.generate_dictionary_hash_table(story_data, dict_base, 3)
      assert mask == 2047
      assert byte_size(bin) == 2048 * 16

      # Verify entries exist in the binary (stored as little-endian 32-bit in the hash table)
      # The assembler uses <<w1::32-little>>
      assert String.contains?(bin, <<0x44, 0x33, 0x22, 0x11>>)
      assert String.contains?(bin, <<0x88, 0x77, 0x66, 0x55>>)
    end
  end
end
