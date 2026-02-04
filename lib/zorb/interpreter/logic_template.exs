defmodule MOD_NAME do
  use Orb
  Orb.Memory.pages(16)

  import Bitwise
  import Kernel, except: [and: 2, or: 2, if: 2]
  import Orb.I32, except: [global: 1, cond: 1, load: 1, and: 2, or: 2, xor: 2, if: 2]
  import Orb.DSL
  import Orb.Control

  alias Orb.I32
  alias Orb.Memory
  require Zorb.Interpreter.Types
  alias Zorb.Interpreter.Types, as: T
  alias Zorb.Capsule.Host, as: ZIO
  import Zorb.Interpreter.Logic.Helpers

  Orb.Import.register(Zorb.Capsule.Host)

  Orb.Memory.initial_data!(0, STORY_DATA)
  Orb.Memory.initial_data!(0x80000, UNICODE_DATA)
  Orb.Memory.initial_data!(0x81000, ALPHABETS_DATA)

  @logic_story_data STORY_DATA

  global do
    @pc 0
    @version V_INIT
    @sp 0
    @fp 0
    @csp 0
    @stack_base 0x90000
    @call_stack_base 0x98000
    @globals_base GB_INIT
    @static_memory_base SB_INIT
    @dictionary_base DB_INIT
    @object_table_base OB_INIT
    @object_table_start 0
    @abbreviations_base AB_INIT
    @next_alphabet -1
    @abbrev_mode 0
    @recursion_depth 0
    @packed_address_shift PAS_INIT
    @routine_offset RO_INIT
    @string_offset SO_INIT
    @stream3_table 0
    @stream3_active 0
    @object_entry_size OES_INIT
    @object_parent_offset PO_INIT
    @object_sibling_offset SOJ_INIT
    @object_child_offset CO_INIT
    @object_property_table_offset PTO_INIT
    @random_state 1
    @story_len STORY_LEN
    @capabilities 0
    @zscii_state 0
    @zscii_high 0
    @unicode_table_base UTB_INIT
    @current_font 1
    @current_alphabet 0
    @halted 0
  end

  # Injected Logic Body
  LOGIC_BODY
end
