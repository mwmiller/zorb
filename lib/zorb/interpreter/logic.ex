defmodule Zorb.Interpreter.Logic do
  @moduledoc """
  Core Z-machine implementation logic for optimized Game Capsules.
  """
  import Bitwise

  defmacro __using__(opts) do
    quote do
      @logic_story_data unquote(Keyword.get(opts, :story_data))
      @before_compile Zorb.Interpreter.Logic
    end
  end

  defmacro __before_compile__(env) do
    story_data = Module.get_attribute(env.module, :logic_story_data)

    IO.puts("Zorb: Logic transformation starting for #{env.module}...")

    logic_path = Path.join(Path.dirname(__ENV__.file), "logic_body.exs")
    logic_body = File.read!(logic_path)

    v = :binary.at(story_data, 0)

    {v_init, sb_init, gb_init, db_init, ob_init, ab_init, pas_init, ro_init, so_init, oes_init,
     po_init, soj_init, co_init, pto_init, utb_init} = {
      v,
      :binary.at(story_data, 14) <<< 8 ||| :binary.at(story_data, 15),
      :binary.at(story_data, 12) <<< 8 ||| :binary.at(story_data, 13),
      :binary.at(story_data, 8) <<< 8 ||| :binary.at(story_data, 9),
      :binary.at(story_data, 10) <<< 8 ||| :binary.at(story_data, 11),
      :binary.at(story_data, 0x18) <<< 8 ||| :binary.at(story_data, 0x19),
      if(v <= 3, do: 1, else: 2),
      if(v in 6..7,
        do: (:binary.at(story_data, 0x28) <<< 8 ||| :binary.at(story_data, 0x29)) * 8,
        else: 0
      ),
      if(v in 6..7,
        do: (:binary.at(story_data, 0x2A) <<< 8 ||| :binary.at(story_data, 0x2B)) * 8,
        else: 0
      ),
      if(v <= 3, do: 9, else: 14),
      if(v <= 3, do: 4, else: 6),
      if(v <= 3, do: 5, else: 8),
      if(v <= 3, do: 6, else: 10),
      if(v <= 3, do: 7, else: 12),
      0x80000
    }

    alphabets =
      "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ 0123456789.,!?_#'\"/\\<-:() \r0123456789.,!?_#'\"/\\-:()"

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
      0x2122,
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
    unicode_list = :binary.bin_to_list(unicode_bin)
    alphabets_list = :binary.bin_to_list(alphabets)

    binding = [
      story_list: :binary.bin_to_list(story_data),
      unicode_list: unicode_list,
      alphabets_list: alphabets_list
    ]

    parts = [
      "import Bitwise",
      "require Orb",
      "import Orb",
      "import Orb.I32, except: [global: 1, cond: 1, and: 2, or: 2, xor: 2]",
      "import Orb.Numeric.DSL, only: [and: 2]",
      "alias Orb.I32",
      "alias Orb.Memory",
      "alias Zorb.Interpreter.Types, as: T",
      "alias Zorb.Capsule.Host, as: ZIO",
      "import Orb.Control",
      "import Zorb.Interpreter.Logic.Helpers",
      "Orb.Import.register(Zorb.Capsule.Host)",
      "Orb.Memory.initial_data!(0, [u8: story_list])",
      "Orb.Memory.initial_data!(0x80000, [u8: unicode_list])",
      "Orb.Memory.initial_data!(0x81000, [u8: alphabets_list])",
      "global do",
      "  @pc 0",
      "  @version #{v_init}",
      "  @sp 0",
      "  @fp 0",
      "  @csp 0",
      "  @stack_base 0x90000",
      "  @call_stack_base 0x98000",
      "  @globals_base #{gb_init}",
      "  @static_memory_base #{sb_init}",
      "  @dictionary_base #{db_init}",
      "  @object_table_base #{ob_init}",
      "  @object_table_start 0",
      "  @abbreviations_base #{ab_init}",
      "  @next_alphabet -1",
      "  @abbrev_mode 0",
      "  @recursion_depth 0",
      "  @packed_address_shift #{pas_init}",
      "  @routine_offset #{ro_init}",
      "  @string_offset #{so_init}",
      "  @stream3_table 0",
      "  @stream3_active 0",
      "  @object_entry_size #{oes_init}",
      "  @object_parent_offset #{po_init}",
      "  @object_sibling_offset #{soj_init}",
      "  @object_child_offset #{co_init}",
      "  @object_property_table_offset #{pto_init}",
      "  @random_state 1",
      "  @story_len #{byte_size(story_data)}",
      "  @capabilities 0",
      "  @zscii_state 0",
      "  @zscii_high 0",
      "  @unicode_table_base #{utb_init}",
      "  @current_font 1",
      "  @current_alphabet 0",
      "  @halted 0",
      "end",
      logic_body
    ]

    source = Enum.join(parts, "\n")
    Code.eval_string(source, binding, %{env | module: env.module})

    nil
  end
end
