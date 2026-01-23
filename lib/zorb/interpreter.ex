defmodule Zorb.Interpreter.Types do
  defmodule ZChar do
    @behaviour Orb.CustomType
    def wasm_type, do: :i32
  end

  defmodule ZWord do
    @behaviour Orb.CustomType
    def wasm_type, do: :i32
  end

  defmodule Address do
    @behaviour Orb.CustomType
    def wasm_type, do: :i32
  end

  defmodule PackedAddress do
    @behaviour Orb.CustomType
    def wasm_type, do: :i32
  end

  defmodule Object do
    @behaviour Orb.CustomType
    def wasm_type, do: :i32
  end

  defmodule Property do
    @behaviour Orb.CustomType
    def wasm_type, do: :i32
  end

  defmodule Variable do
    @behaviour Orb.CustomType
    def wasm_type, do: :i32
  end
end

defmodule Zorb.Interpreter.ZIO do
  use Orb.Import, name: :zio
  defw(print_char(char: Orb.I32))
  defw(read_char(), Orb.I32)
  # 1=Stack Overflow, 2=Static Memory Write, 3=Illegal Instruction
  defw(halt(reason: Orb.I32))
end

defmodule Zorb.Interpreter do
  use Orb
  alias Zorb.Interpreter.Types, as: T

  defp header_version, do: 0x00
  defp header_initial_pc, do: 0x06
  defp header_dictionary_base, do: 0x08
  defp header_object_table_base, do: 0x0A
  defp header_globals_base, do: 0x0C
  defp header_static_memory_base, do: 0x0E
  defp header_abbreviations_base, do: 0x18

  # Prime number of pages: 832KB
  Memory.pages(13)

  global do
    @pc 0
    @version 0
    @sp 0
    @fp 0
    @stack_base 0
    # 1024 words = 2KB stack
    @stack_max 1024
    @globals_base 0
    @static_memory_base 0
    @dictionary_base 0
    @object_table_base 0
    @object_table_start 0
    @abbreviations_base 0
    # 0=A0, 1=A1, 2=A2
    @alphabet_shift 0
    # 0=none, 1=A1, 2=A2, 3=A3
    @abbrev_mode 0
    @recursion_depth 0
    @packed_address_shift 0
    @object_entry_size 0
    @object_parent_offset 0
    @object_sibling_offset 0
    @object_child_offset 0
    @object_property_table_offset 0

    # Font state (1=Normal, 3=Graphics)

    @current_font 1
  end

  # Font 3 Mapping Data

  @runes [
    {97, 0x16AA, "ᚪ"},
    {98, 0x16D2, "ᛒ"},
    {99, 0x16D7, "ᛇ"},
    {100, 0x16DE, "ᛞ"},
    {101, 0x16E6, "ᛖ"},
    {102, 0x16A0, "ᚠ"},
    {103, 0x16B7, "ᚷ"},
    {104, 0x16BB, "ᚻ"},
    {105, 0x16C1, "ᛁ"},
    {106, 0x16C4, "ᛄ"},
    {107, 0x16E3, "ᛣ"},
    {108, 0x16DA, "ᛚ"},
    {109, 0x16D7, "ᛗ"},
    {110, 0x16BE, "ᚾ"},
    {111, 0x16A9, "ᚩ"},
    {112, 0x16C8, "ᛈ"},
    {113, 0x16B3, "ᚳ"},
    {114, 0x16B1, "ᚱ"},
    {115, 0x16CB, "ᛋ"},
    {116, 0x16CF, "ᛏ"},
    {117, 0x16A2, "ᚢ"},
    {118, 0x16E0, "ᛠ"},
    {119, 0x16B9, "ᚹ"},
    {120, 0x16C9, "ᛉ"},
    {121, 0x16A3, "ᚣ"},
    {122, 0x16DF, "ᛟ"}
  ]

  @graphics [
    {33, 0x2192, "→ (Right Arrow)"},
    {34, 0x2190, "← (Left Arrow)"},
    {35, 0x2571, "╱ (RDIAG)"},
    {36, 0x2572, "╲ (LDIAG)"},
    {37, 0x2588, "█ (SOLID)"},
    {38, 0x2584, "▄ (BOT)"},
    {39, 0x2580, "▀ (TOP)"},
    {40, 0x258C, "▌ (LSID)"},
    {41, 0x2590, "▐ (RSID)"},
    {42, 0x2534, "┴ (NCON)"},
    {43, 0x252C, "┬ (SCON)"},
    {44, 0x251C, "├ (ECON)"},
    {45, 0x2524, "┤ (WCON)"},
    {46, 0x2514, "└ (BLC)"},
    {47, 0x250C, "┌ (TLC)"},
    {48, 0x2510, "┐ (TRC)"},
    {49, 0x2518, "┘ (BRC)"},
    {50, 0x256F, "╯ (SWCON)"},
    {51, 0x2570, "╰ (NWCON)"},
    {52, 0x256D, "╭ (NECON)"},
    {53, 0x256E, "╮ (SECON)"},
    {54, 0x2593, "▓ (ISOLID)"},
    {71, 0x2510, "┐ (TRCORNER)"},
    {72, 0x2518, "┘ (BRCORNER)"},
    {73, 0x2514, "└ (BLCORNER)"},
    {74, 0x250C, "┌ (TLCORNER)"},
    {75, 0x2500, "─ (TOPEDGE)"},
    {76, 0x2500, "─ (BOTEDGE)"},
    {77, 0x2502, "│ (LEDGE)"},
    {78, 0x2502, "│ (REDGE)"},
    {88, 0x2524, "┤ (LCAP)"},
    {89, 0x251C, "├ (RCAP)"},
    {90, 0x2573, "╳ (XCROSS)"},
    {91, 0x253C, "┼ (HVCROSS)"},
    {92, 0x2191, "↑ (UARROW)"},
    {93, 0x2193, "↓ (DARROW)"},
    {94, 0x2195, "↕ (UDARROW)"},
    {95, 0x25AB, "▫ (SMBOX)"},
    {96, 0x003F, "? (QMARK)"},
    {123, 0x21E7, "⬆ (IUARROW)"},
    {124, 0x21E9, "⬇ (IDARROW)"},
    {125, 0x21D5, "⇕ (IUDARROW)"},
    {126, 0x00BF, "¿ (IQMARK)"}
  ]

  Orb.Import.register(Zorb.Interpreter.ZIO)

  defw init(stack_offset: T.Address) do
    @version = Memory.load!(I32.U8, header_version())
    @pc = read_word(header_initial_pc())
    @globals_base = read_word(header_globals_base())
    @dictionary_base = read_word(header_dictionary_base())
    @object_table_base = read_word(header_object_table_base())
    @static_memory_base = read_word(header_static_memory_base())
    @abbreviations_base = read_word(header_abbreviations_base())
    @stack_base = stack_offset
    @sp = 0
    @fp = 0
    @recursion_depth = 0
    @current_font = 1

    if @version <= 3 do
      @packed_address_shift = 1
      @object_entry_size = 9
      @object_parent_offset = 4
      @object_sibling_offset = 5
      @object_child_offset = 6
      @object_property_table_offset = 7
      @object_table_start = @object_table_base + 62
    else
      @packed_address_shift = 2
      @object_entry_size = 14
      @object_parent_offset = 6
      @object_sibling_offset = 8
      @object_child_offset = 10
      @object_property_table_offset = 12
      @object_table_start = @object_table_base + 126
    end

    if @version === 8, do: @packed_address_shift = 3

    push_stack(0)
    push_stack(0)
    push_stack(0xFF)
    push_stack(0)
    @fp = 0
  end

  # Load the story data into memory.
  defw load_story(story_ptr: T.Address, len: I32), i: I32 do
    i = 0

    loop CopyLoop do
      if I32.lt_u(i, len) do
        Memory.store!(I32.U8, i, Memory.load!(I32.U8, story_ptr + i))
        i = i + 1
        CopyLoop.continue()
      end
    end
  end

  defw unpack_address(address: T.PackedAddress), T.Address do
    I32.shl(address, @packed_address_shift)
  end

  # Guard against writes to static memory.
  defw write_word(address: T.Address, value: I32) do
    if I32.ge_u(address, @static_memory_base), do: return(Zorb.Interpreter.ZIO.halt(2))
    Memory.store!(I32.U8, address, I32.shr_u(value, 8))
    Memory.store!(I32.U8, address + 1, I32.band(value, 0xFF))
  end

  defw write_byte(address: T.Address, value: I32) do
    if I32.ge_u(address, @static_memory_base), do: return(Zorb.Interpreter.ZIO.halt(2))
    Memory.store!(I32.U8, address, I32.band(value, 0xFF))
  end

  defw read_variable(var: T.Variable), I32 do
    if var === 0, do: return(pop_stack())
    if var < 16, do: return(read_stack(@fp + 4 + (var - 1)))
    read_word(@globals_base + I32.shl(var - 16, 1))
  end

  defw write_variable(var: T.Variable, value: I32) do
    if var === 0 do
      push_stack(value)
      return()
    end

    if var < 16 do
      write_stack(@fp + 4 + (var - 1), value)
      return()
    end

    write_word(@globals_base + I32.shl(var - 16, 1), value)
  end

  # Guard against stack overflow.
  defw push_stack(value: I32) do
    if I32.ge_u(@sp, @stack_max), do: return(Zorb.Interpreter.ZIO.halt(1))
    write_stack(@sp, value)
    @sp = @sp + 1
  end

  defw pop_stack(), I32 do
    @sp = @sp - 1
    read_stack(@sp)
  end

  defw read_stack(index: I32), I32 do
    Memory.load!(I32.U16, @stack_base + I32.shl(index, 1))
  end

  defw write_stack(index: I32, value: I32) do
    Memory.store!(I32.U16, @stack_base + I32.shl(index, 1), value)
  end

  defw read_byte(address: T.Address), I32 do
    Memory.load!(I32.U8, address)
  end

  defw read_word(address: T.Address), I32 do
    I32.or(I32.shl(Memory.load!(I32.U8, address), 8), Memory.load!(I32.U8, address + 1))
  end

  defw get_pc(), T.Address do
    @pc
  end

  defw set_pc(new_pc: T.Address) do
    @pc = new_pc
  end

  defw fetch_byte(), I32, byte: I32 do
    byte = read_byte(@pc)
    @pc = @pc + 1
    byte
  end

  defw fetch_word(), I32, word: I32 do
    word = read_word(@pc)
    @pc = @pc + 2
    word
  end

  defw fetch_operand(type: I32), I32 do
    if type === 0, do: return(fetch_word())
    if type === 1, do: return(fetch_byte())
    if type === 2, do: return(read_variable(fetch_byte()))
    0
  end

  defw get_object_address(object: T.Object), T.Address do
    @object_table_start + (object - 1) * @object_entry_size
  end

  defw get_object_parent(object: T.Object), T.Object, addr: T.Address do
    addr = get_object_address(object)
    if @version <= 3, do: return(read_byte(addr + @object_parent_offset))
    read_word(addr + @object_parent_offset)
  end

  defw get_object_sibling(object: T.Object), T.Object, addr: T.Address do
    addr = get_object_address(object)
    if @version <= 3, do: return(read_byte(addr + @object_sibling_offset))
    read_word(addr + @object_sibling_offset)
  end

  defw get_object_child(object: T.Object), T.Object, addr: T.Address do
    addr = get_object_address(object)
    if @version <= 3, do: return(read_byte(addr + @object_child_offset))
    read_word(addr + @object_child_offset)
  end

  defw get_prop_table_address(object: T.Object), T.Address, addr: T.Address do
    addr = get_object_address(object)
    read_word(addr + @object_property_table_offset)
  end

  defw get_prop_address(object: T.Object, property: T.Property), T.Address,
    addr: T.Address,
    byte: I32,
    size: I32,
    prop_num: I32,
    byte2: I32 do
    addr = get_prop_table_address(object)
    addr = addr + I32.shl(read_byte(addr), 1) + 1

    loop PropLoop do
      byte = read_byte(addr)
      if byte === 0, do: return(0)

      if @version <= 3 do
        prop_num = I32.band(byte, 0x1F)
        size = I32.shr_u(byte, 5) + 1
        if prop_num === property, do: return(addr + 1)
        addr = addr + size + 1
      else
        prop_num = I32.band(byte, 0x3F)

        if I32.band(byte, 0x80) > 0 do
          byte2 = read_byte(addr + 1)
          size = I32.band(byte2, 0x3F)
          if size === 0, do: size = 64
          if prop_num === property, do: return(addr + 2)
          addr = addr + size + 2
        else
          size = if I32.band(byte, 0x40) > 0, do: I32.const(2), else: I32.const(1)
          if prop_num === property, do: return(addr + 1)
          addr = addr + size + 1
        end
      end

      PropLoop.continue(if: prop_num > property)
    end

    0
  end

  defw step(), byte: I32, types_byte: I32, opcode: I32, types_byte2: I32 do
    byte = fetch_byte()

    # 2OP
    if byte < 0x80 do
      execute_2op(
        I32.band(byte, 0x1F),
        fetch_operand(
          if I32.band(byte, 0x40) > 0, result: I32, do: I32.const(2), else: I32.const(1)
        ),
        fetch_operand(
          if I32.band(byte, 0x20) > 0, result: I32, do: I32.const(2), else: I32.const(1)
        )
      )

      return()
    end

    # 1OP
    if byte < 0xB0 do
      execute_1op(I32.band(byte, 0x0F), fetch_operand(I32.band(I32.shr_u(byte, 4), 0x03)))
      return()
    end

    # 0OP
    if byte < 0xC0 do
      execute_0op(I32.band(byte, 0x0F))
      return()
    end

    opcode = I32.band(byte, 0x1F)
    types_byte = fetch_byte()

    # VAR Forms of 2OP (0xC0 - 0xDF)
    if byte < 0xE0 do
      execute_2op(
        opcode,
        fetch_operand(I32.band(I32.shr_u(types_byte, 6), 0x03)),
        fetch_operand(I32.band(I32.shr_u(types_byte, 4), 0x03))
      )

      return()
    end

    # VAR Opcodes (0xE0 - 0xFF)
    if I32.or(opcode === 0x0C, opcode === 0x1A) do
      types_byte2 = fetch_byte()

      execute_var8(
        opcode,
        fetch_operand(I32.band(I32.shr_u(types_byte, 6), 0x03)),
        fetch_operand(I32.band(I32.shr_u(types_byte, 4), 0x03)),
        fetch_operand(I32.band(I32.shr_u(types_byte, 2), 0x03)),
        fetch_operand(I32.band(types_byte, 0x03)),
        fetch_operand(I32.band(I32.shr_u(types_byte2, 6), 0x03)),
        fetch_operand(I32.band(I32.shr_u(types_byte2, 4), 0x03)),
        fetch_operand(I32.band(I32.shr_u(types_byte2, 2), 0x03)),
        fetch_operand(I32.band(types_byte2, 0x03))
      )

      return()
    end

    execute_var(
      opcode,
      fetch_operand(I32.band(I32.shr_u(types_byte, 6), 0x03)),
      fetch_operand(I32.band(I32.shr_u(types_byte, 4), 0x03)),
      fetch_operand(I32.band(I32.shr_u(types_byte, 2), 0x03)),
      fetch_operand(I32.band(types_byte, 0x03))
    )
  end

  defw execute_2op(opcode: I32, op1: I32, op2: I32),
    addr: T.Address,
    byte: I32,
    size: I32,
    prop_num: I32,
    old_child: T.Object do
    if opcode === 1, do: return(fetch_branch(op1 === op2))
    if opcode === 2, do: return(fetch_branch(I32.lt_s(op1, op2)))
    if opcode === 3, do: return(fetch_branch(I32.gt_s(op1, op2)))

    # test_attr
    if opcode === 4 do
      addr = get_object_address(op1)
      byte = read_byte(addr + I32.shr_u(op2, 3))
      fetch_branch(I32.band(byte, I32.shl(1, 7 - I32.band(op2, 7))) !== 0)
      return()
    end

    # set_attr
    if opcode === 5 do
      addr = get_object_address(op1)
      byte = read_byte(addr + I32.shr_u(op2, 3))
      write_byte(addr + I32.shr_u(op2, 3), I32.or(byte, I32.shl(1, 7 - I32.band(op2, 7))))
      return()
    end

    # clear_attr
    if opcode === 6 do
      addr = get_object_address(op1)
      byte = read_byte(addr + I32.shr_u(op2, 3))

      write_byte(
        addr + I32.shr_u(op2, 3),
        I32.band(byte, I32.xor(I32.shl(1, 7 - I32.band(op2, 7)), 0xFF))
      )

      return()
    end

    if opcode === 7, do: return(fetch_result_and_store(I32.band(op1, op2)))
    if opcode === 8, do: return(fetch_result_and_store(I32.or(op1, op2)))
    if opcode === 9, do: return(fetch_branch(I32.band(op1, op2) === op2))
    if opcode === 13, do: return(write_variable(op1, op2))

    # insert_obj
    if opcode === 14 do
      do_remove_obj(op1)
      old_child = get_object_child(op2)
      set_object_child(op2, op1)
      set_object_sibling(op1, old_child)
      set_object_parent(op1, op2)
      return()
    end

    if opcode === 15, do: return(fetch_result_and_store(read_word(op1 + I32.shl(op2, 1))))
    if opcode === 16, do: return(fetch_result_and_store(read_byte(op1 + op2)))

    if opcode === 17 do
      addr = get_prop_address(op1, op2)

      if addr === 0 do
        fetch_result_and_store(read_word(@object_table_base + I32.shl(op2 - 1, 1)))
      else
        if @version <= 3 do
          if I32.shr_u(read_byte(addr - 1), 5) === 0,
            do: fetch_result_and_store(read_byte(addr)),
            else: fetch_result_and_store(read_word(addr))
        else
          byte = read_byte(addr - 1)

          if I32.band(byte, 0x80) > 0 do
            size = I32.band(read_byte(addr - 1), 0x3F)

            if size === 1,
              do: fetch_result_and_store(read_byte(addr)),
              else: fetch_result_and_store(read_word(addr))
          else
            size = if I32.band(byte, 0x40) > 0, do: I32.const(2), else: I32.const(1)

            if size === 1,
              do: fetch_result_and_store(read_byte(addr)),
              else: fetch_result_and_store(read_word(addr))
          end
        end
      end

      return()
    end

    if opcode === 18, do: return(fetch_result_and_store(get_prop_address(op1, op2)))

    if opcode === 19 do
      addr = get_prop_table_address(op1)
      addr = addr + I32.shl(read_byte(addr), 1) + 1

      if op2 === 0 do
        fetch_result_and_store(I32.band(read_byte(addr), 0x1F))
        return()
      end

      loop FindNextProp do
        byte = read_byte(addr)
        if byte === 0, do: return(fetch_result_and_store(0))
        prop_num = I32.band(byte, 0x1F)
        size = I32.shr_u(byte, 5) + 1

        if prop_num === op2 do
          fetch_result_and_store(I32.band(read_byte(addr + size + 1), 0x1F))
          return()
        end

        addr = addr + size + 1
        FindNextProp.continue(if: prop_num > op2)
      end

      fetch_result_and_store(0)
      return()
    end

    if opcode === 20, do: return(fetch_result_and_store(op1 + op2))
    if opcode === 21, do: return(fetch_result_and_store(op1 - op2))
    if opcode === 22, do: return(fetch_result_and_store(op1 * op2))
    if opcode === 23, do: return(fetch_result_and_store(I32.div_s(op1, op2)))
    if opcode === 24, do: return(fetch_result_and_store(I32.rem_s(op1, op2)))
  end

  defw execute_1op(opcode: I32, op1: I32), sibling: T.Object, child: T.Object do
    if opcode === 0, do: return(fetch_branch(op1 === 0))

    if opcode === 1 do
      sibling = get_object_sibling(op1)
      fetch_result_and_store(sibling)
      fetch_branch(sibling !== 0)
      return()
    end

    if opcode === 2 do
      child = get_object_child(op1)
      fetch_result_and_store(child)
      fetch_branch(child !== 0)
      return()
    end

    if opcode === 3, do: return(fetch_result_and_store(get_object_parent(op1)))

    if opcode === 4 do
      if op1 === 0, do: return(fetch_result_and_store(0))
      fetch_result_and_store(get_prop_len(op1))
      return()
    end

    if opcode === 5, do: return(write_variable(op1, read_variable(op1) + 1))
    if opcode === 6, do: return(write_variable(op1, read_variable(op1) - 1))
    if opcode === 9, do: return(do_remove_obj(op1))

    # print_obj
    if opcode === 10 do
      print_zstring(get_prop_table_address(op1) + 1)
      return()
    end

    if opcode === 11, do: return(do_return(op1))

    if opcode === 12 do
      @pc = @pc + op1 - 2
      return()
    end

    if opcode === 14, do: return(fetch_result_and_store(read_variable(op1)))
    if opcode === 15, do: return(fetch_result_and_store(I32.xor(op1, 0xFFFF)))
  end

  defw get_prop_len(data_addr: T.Address), I32, byte: I32 do
    if data_addr === 0, do: return(0)
    byte = read_byte(data_addr - 1)
    if @version <= 3, do: return(I32.shr_u(byte, 5) + 1)

    if I32.band(byte, 0x80) > 0 do
      byte = I32.band(byte, 0x3F)
      if byte === 0, do: return(64), else: return(byte)
    end

    if I32.band(byte, 0x40) > 0, do: return(2), else: return(1)
    I32.const(0)
  end

  defw do_remove_obj(object: T.Object), parent: T.Object, curr: T.Object, next: T.Object do
    parent = get_object_parent(object)
    if parent === 0, do: return()

    curr = get_object_child(parent)

    if curr === object do
      set_object_child(parent, get_object_sibling(object))
    else
      loop FindPrev do
        next = get_object_sibling(curr)

        if next === object do
          set_object_sibling(curr, get_object_sibling(object))
          # break
          curr = 0
        else
          curr = next
        end

        FindPrev.continue(if: curr !== 0)
      end
    end

    set_object_parent(object, 0)
    set_object_sibling(object, 0)
  end

  defw set_object_parent(object: T.Object, val: T.Object), addr: T.Address do
    addr = get_object_address(object)
    if @version <= 3, do: write_byte(addr + 4, val), else: write_word(addr + 6, val)
  end

  defw set_object_sibling(object: T.Object, val: T.Object), addr: T.Address do
    addr = get_object_address(object)
    if @version <= 3, do: write_byte(addr + 5, val), else: write_word(addr + 8, val)
  end

  defw set_object_child(object: T.Object, val: T.Object), addr: T.Address do
    addr = get_object_address(object)
    if @version <= 3, do: write_byte(addr + 6, val), else: write_word(addr + 10, val)
  end

  defw execute_var(opcode: I32, op1: I32, op2: I32, op3: I32, op4: I32),
    addr: T.Address do
    if opcode === 0x00 do
      if op1 === 0, do: return(fetch_result_and_store(0))
      do_call(unpack_address(op1), fetch_byte())
      return()
    end

    if opcode === 0x01, do: return(write_word(op1 + I32.shl(op2, 1), op3))
    if opcode === 0x02, do: return(write_byte(op1 + op2, op3))

    if opcode === 0x03 do
      addr = get_prop_address(op1, op2)

      if addr !== 0 do
        if I32.shr_u(read_byte(addr - 1), 5) === 0,
          do: write_byte(addr, op3),
          else: write_word(addr, op3)
      end

      return()
    end

    # read
    if opcode === 0x04 do
      read_input(op1)
      if op2 !== 0, do: do_tokenise(op1, op2, 0)
      return()
    end

    if opcode === 0x05, do: return(print_output_char(op1))

    # print_num
    if opcode === 0x06 do
      print_number(op1)
      return()
    end

    if opcode === 0x07, do: return(fetch_result_and_store(1))
    if opcode === 0x08, do: return(push_stack(op1))
    if opcode === 0x09, do: return(write_variable(op1, pop_stack()))

    # read_char
    if opcode === 0x16 do
      fetch_result_and_store(Zorb.Interpreter.ZIO.read_char())
      return()
    end

    if opcode === 0x19, do: return(do_call(unpack_address(op1), 0xFF))
    if opcode === 0x1B, do: return(do_tokenise(op1, op2, op3))
  end

  defw execute_0op(opcode: I32) do
    if opcode === 0, do: return(do_return(1))
    if opcode === 1, do: return(do_return(0))
    if opcode === 2, do: return(print_zstring(0))
    if opcode === 8, do: return(do_return(pop_stack()))
    if opcode === 0x0E, do: return(execute_ext())
  end

  defw execute_ext(), opcode: I32, types: I32 do
    opcode = fetch_byte()
    types = fetch_byte()

    # set_font
    if opcode === 0x04 do
      fetch_result_and_store(set_font(fetch_operand(I32.band(I32.shr_u(types, 6), 0x03))))
      return()
    end

    # print_unicode
    if opcode === 0x0B do
      Zorb.Interpreter.ZIO.print_char(fetch_operand(I32.band(I32.shr_u(types, 6), 0x03)))
      return()
    end

    # check_unicode
    if opcode === 0x0C do
      # Consume the char argument (we ignore it and return 3)
      fetch_operand(I32.band(I32.shr_u(types, 6), 0x03))
      fetch_result_and_store(3)
      return()
    end
  end

  defw set_font(font: I32), I32, old: I32 do
    if I32.eq(font, 1) do
      old = @current_font
      @current_font = 1
      return(old)
    end

    if I32.eq(font, 3) do
      old = @current_font
      @current_font = 3
      return(old)
    end

    0
  end

  mapping = Macro.escape(@runes ++ @graphics)

  defw map_font3(char: I32), I32 do
    Enum.map(unquote(mapping), fn {k, v, _label} ->
      if char === k, do: return(v)
    end)

    char
  end

  defw print_output_char(char: I32) do
    if @current_font === 3 do
      char = map_font3(char)
    end

    Zorb.Interpreter.ZIO.print_char(char)
  end

  defw read_input(text_buf: T.Address), max_len: I32, i: I32, char: I32 do
    max_len = read_byte(text_buf)

    if @version <= 4 do
      i = 1
    else
      i = 2
    end

    loop ReadLoop do
      char = Zorb.Interpreter.ZIO.read_char()

      # 13 is Newline
      if char === 13 do
        # Terminate with 0
        write_byte(text_buf + i, 0)
        return()
      end

      # Only write if we have space
      if i < max_len do
        # ZSCII: Lowercase conversion could happen here but usually handled by dictionary lookups
        if char >= 65 do
          if char <= 90 do
            char = char + 32
          end
        end

        write_byte(text_buf + i, char)
        i = i + 1
      end

      ReadLoop.continue()
    end
  end

  defw print_number(value: I32), div: I32, digit: I32 do
    if value === 0 do
      # '0'
      print_output_char(48)
      return()
    end

    if value < 0 do
      # '-'
      print_output_char(45)
      value = 0 - value
    end

    div = 10000
    if value < 10000, do: div = 1000
    if value < 1000, do: div = 100
    if value < 100, do: div = 10
    if value < 10, do: div = 1

    loop DigitLoop do
      if div > 0 do
        digit = value / div
        # '0' + digit
        print_output_char(48 + digit)
        value = I32.rem_s(value, div)
        div = div / 10
        DigitLoop.continue()
      end
    end
  end

  defwp char_to_zchar(char: I32), T.ZChar do
    if I32.band(I32.ge_u(char, 97), I32.le_u(char, 122)), do: return(char - 97 + 6)
    I32.const(5)
  end

  defwp get_max_words(), I32 do
    if @version <= 3, do: return(I32.const(2))
    I32.const(3)
  end

  defw encode_word(input_addr: T.Address, input_len: I32, output_addr: T.Address),
    i: I32,
    word_idx: I32,
    z1: T.ZChar,
    z2: T.ZChar,
    z3: T.ZChar,
    word: T.ZWord,
    max_words: I32,
    addr: T.Address do
    max_words = get_max_words()
    i = 0
    word_idx = 0

    loop WordLoop do
      z1 = 5
      z2 = 5
      z3 = 5

      if I32.lt_u(i, input_len) do
        z1 = char_to_zchar(read_byte(input_addr + i))
        i = i + 1
      end

      if I32.lt_u(i, input_len) do
        z2 = char_to_zchar(read_byte(input_addr + i))
        i = i + 1
      end

      if I32.lt_u(i, input_len) do
        z3 = char_to_zchar(read_byte(input_addr + i))
        i = i + 1
      end

      word = I32.or(I32.shl(z1, 10), I32.or(I32.shl(z2, 5), z3))
      word_idx = word_idx + 1
      if word_idx === max_words, do: word = I32.or(word, I32.const(0x8000))

      # Bypass write guard for internal encoding buffer
      addr = output_addr + (word_idx - 1) * 2
      Memory.store!(I32.U8, addr, I32.shr_u(word, 8))
      Memory.store!(I32.U8, addr + 1, I32.band(word, 0xFF))

      WordLoop.continue(if: I32.lt_u(word_idx, max_words))
    end
  end

  defwp compare_encoded(addr1: T.Address, addr2: T.Address), I32,
    w1_a: I32,
    w1_b: I32,
    w2_a: I32,
    w2_b: I32,
    w3_a: I32,
    w3_b: I32 do
    w1_a = read_word(addr1)
    w1_b = read_word(addr2)
    if w1_a !== w1_b, do: return(if I32.gt_u(w1_a, w1_b), do: I32.const(1), else: I32.const(2))

    w2_a = read_word(addr1 + 2)
    w2_b = read_word(addr2 + 2)
    if w2_a !== w2_b, do: return(if I32.gt_u(w2_a, w2_b), do: I32.const(1), else: I32.const(2))

    if @version >= 4 do
      w3_a = read_word(addr1 + 4)
      w3_b = read_word(addr2 + 4)
      if w3_a !== w3_b, do: return(if I32.gt_u(w3_a, w3_b), do: I32.const(1), else: I32.const(2))
    end

    I32.const(0)
  end

  defw lookup_dictionary(encoded_addr: T.Address, dict_addr: T.Address), T.Address,
    num_separators: I32,
    entry_len: I32,
    num_entries: I32,
    entries_start: T.Address,
    low: I32,
    high: I32,
    mid: I32,
    cmp: I32,
    entry_addr: T.Address do
    if dict_addr === 0, do: dict_addr = @dictionary_base
    num_separators = read_byte(dict_addr)
    entry_len = read_byte(dict_addr + num_separators + 1)
    num_entries = read_word(dict_addr + num_separators + 2)
    entries_start = dict_addr + num_separators + 4

    low = 0
    high = num_entries - 1

    loop SearchLoop do
      if I32.le_s(low, high) do
        mid = (low + high) / 2
        entry_addr = entries_start + mid * entry_len

        cmp = compare_encoded(encoded_addr, entry_addr)
        if cmp === 0, do: return(entry_addr)

        if cmp === 1 do
          low = mid + 1
        else
          high = mid - 1
        end

        SearchLoop.continue()
      end
    end

    0
  end

  defw is_separator(char: I32, dict_addr: T.Address), I32, num: I32, i: I32, result: I32 do
    if dict_addr === 0, do: dict_addr = @dictionary_base
    num = read_byte(dict_addr)
    i = 0
    result = 0

    loop SepLoop do
      if I32.lt_u(i, num) do
        if read_byte(dict_addr + 1 + i) === char do
          result = 1
        else
          i = i + 1
          SepLoop.continue()
        end
      end
    end

    result
  end

  defwp get_text_start_addr(text_buf: T.Address), T.Address do
    if @version <= 4, do: return(text_buf + 1)
    text_buf + 2
  end

  defwp get_token_offset(word_start: I32), I32 do
    if @version <= 4, do: return(word_start + 1)
    word_start + 2
  end

  defwp get_text_len_v1_4(text_buf: T.Address, text_start: T.Address), I32,
    i: I32,
    text_len: I32 do
    i = 0
    text_len = read_byte(text_buf)

    loop ScanZero do
      if I32.lt_u(i, text_len) do
        if read_byte(text_start + i) !== 0 do
          i = i + 1
          ScanZero.continue()
        end
      end
    end

    i
  end

  defw do_tokenise(text_buf: T.Address, parse_buf: T.Address, dict_addr: T.Address),
    text_len: I32,
    i: I32,
    word_start: I32,
    word_len: I32,
    char: I32,
    encoded: T.Address,
    dict_match: T.Address,
    token_count: I32,
    parse_max: I32,
    addr: T.Address,
    text_start: T.Address do
    text_start = get_text_start_addr(text_buf)
    parse_max = read_byte(parse_buf)
    token_count = 0
    encoded = 0x10000

    if @version <= 4 do
      text_len = get_text_len_v1_4(text_buf, text_start)
    else
      text_len = read_byte(text_buf + 1)
    end

    i = 0

    loop TokenLoop do
      if I32.lt_u(i, text_len) do
        char = read_byte(text_start + i)

        if char === 32 do
          i = i + 1
          TokenLoop.continue()
        end

        word_start = i

        if is_separator(char, dict_addr) do
          word_len = 1
          i = i + 1
        else
          loop WordLoop do
            i = i + 1

            if I32.lt_u(i, text_len) do
              char = read_byte(text_start + i)

              if I32.band(char !== 32, I32.eqz(is_separator(char, dict_addr))),
                do: WordLoop.continue()
            end
          end

          word_len = i - word_start
        end

        if I32.lt_u(token_count, parse_max) do
          encode_word(text_start + word_start, word_len, encoded)
          dict_match = lookup_dictionary(encoded, dict_addr)
          addr = parse_buf + 2 + token_count * 4
          write_word(addr, dict_match)
          Memory.store!(I32.U8, addr + 2, word_len)
          Memory.store!(I32.U8, addr + 3, get_token_offset(word_start))
          token_count = token_count + 1
        end

        TokenLoop.continue()
      end
    end

    write_byte(parse_buf + 1, token_count)
  end

  defw execute_var8(
         opcode: I32,
         op1: I32,
         op2: I32,
         op3: I32,
         op4: I32,
         op5: I32,
         op6: I32,
         op7: I32,
         op8: I32
       ) do
    if opcode === 0x0C, do: return(do_call(unpack_address(op1), fetch_byte()))
    if opcode === 0x1A, do: return(do_call(unpack_address(op1), 0xFF))
  end

  defw print_zstring(word_addr: T.Address),
    word: I32,
    done: I32,
    z1: T.ZChar,
    z2: T.ZChar,
    z3: T.ZChar,
    saved_shift: I32 do
    if word_addr !== 0 do
      # If address provided, set PC temporarily (hacky but standard way to reuse print_zstring)
      # But here we are using global @pc.
      # Standard approach: print_zstring usually reads from @pc.
      # To read from arbitrary address, we need to pass address or have a separate loop.
      # Re-implementing simplified loop for arbitrary address.

      loop AddrLoop do
        word = read_word(word_addr)
        word_addr = word_addr + 2

        done = I32.band(word, 0x8000)
        z1 = I32.band(I32.shr_u(word, 10), 0x1F)
        z2 = I32.band(I32.shr_u(word, 5), 0x1F)
        z3 = I32.band(word, 0x1F)
        decode_zchar(z1)
        decode_zchar(z2)
        decode_zchar(z3)
        AddrLoop.continue(if: done === 0)
      end

      return()
    end

    @recursion_depth = @recursion_depth + 1
    if @recursion_depth > 2, do: return()
    saved_shift = @alphabet_shift
    @alphabet_shift = 0
    @abbrev_mode = 0

    loop DecodeLoop do
      word = fetch_word()
      done = I32.band(word, 0x8000)
      z1 = I32.band(I32.shr_u(word, 10), 0x1F)
      z2 = I32.band(I32.shr_u(word, 5), 0x1F)
      z3 = I32.band(word, 0x1F)
      decode_zchar(z1)
      decode_zchar(z2)
      decode_zchar(z3)
      DecodeLoop.continue(if: done === 0)
    end

    @alphabet_shift = saved_shift
    @recursion_depth = @recursion_depth - 1
  end

  defw decode_zchar(zchar: T.ZChar), old_pc: T.Address, abbrev_addr: T.Address do
    if @abbrev_mode > 0 do
      abbrev_addr =
        read_word(@abbreviations_base + I32.shl(I32.shl(@abbrev_mode - 1, 5) + zchar, 1))

      abbrev_addr = unpack_address(abbrev_addr)
      old_pc = @pc
      @pc = abbrev_addr
      @abbrev_mode = 0
      print_zstring(0)
      @pc = old_pc
      return()
    end

    if zchar >= 1 do
      if zchar <= 3 do
        @abbrev_mode = zchar
        return()
      end
    end

    if zchar === 0 do
      print_output_char(32)
      @alphabet_shift = 0
      return()
    end

    if zchar === 4, do: return(@alphabet_shift = 1)
    if zchar === 5, do: return(@alphabet_shift = 2)

    if @alphabet_shift === 0 do
      print_output_char(zchar + 91)
      return()
    end

    if @alphabet_shift === 1 do
      print_output_char(zchar + 59)
      @alphabet_shift = 0
      return()
    end

    if @alphabet_shift === 2 do
      if zchar === 6,
        do: print_output_char(10),
        else: print_output_char(63)

      @alphabet_shift = 0
      return()
    end
  end

  defw do_call(address: T.PackedAddress, result_var: T.Variable),
    locals_count: I32,
    i: I32,
    old_fp: I32 do
    locals_count = read_byte(address)
    old_fp = @fp
    @fp = @sp
    push_stack(I32.band(@pc, 0xFFFF))
    push_stack(I32.shr_u(@pc, 16))
    push_stack(result_var)
    push_stack(old_fp)
    address = address + 1
    i = 0

    loop InitLocals do
      if @version <= 3 do
        push_stack(read_word(address))
        address = address + 2
      else
        push_stack(0)
      end

      i = i + 1
      InitLocals.continue(if: i < locals_count)
    end

    @pc = address
  end

  defw do_return(value: I32), old_fp: I32, return_pc: T.Address, store_var: T.Variable do
    return_pc = I32.or(read_stack(@fp), I32.shl(read_stack(@fp + 1), 16))
    store_var = read_stack(@fp + 2)
    old_fp = read_stack(@fp + 3)
    if return_pc === 0, do: return()
    @pc = return_pc
    @sp = @fp
    @fp = old_fp
    if store_var !== 0xFF, do: write_variable(store_var, value)
  end

  defw fetch_result_and_store(value: I32), result_var: T.Variable do
    result_var = fetch_byte()
    write_variable(result_var, I32.band(value, 0xFFFF))
  end

  defw fetch_branch(condition: I32), branch_byte: I32 do
    branch_byte = fetch_byte()

    if condition do
      if I32.band(branch_byte, 0x80) > 0, do: do_branch(branch_byte)
    else
      if I32.band(branch_byte, 0x80) === 0, do: do_branch(branch_byte)
    end
  end

  defw do_branch(branch_byte: I32), offset: I32 do
    if I32.band(branch_byte, 0x40) > 0 do
      offset = I32.band(branch_byte, 0x3F)
      if offset === 0, do: return(do_return(0))
      if offset === 1, do: return(do_return(1))
      @pc = @pc + offset - 2
    else
      offset = I32.or(I32.shl(I32.band(branch_byte, 0x3F), 8), fetch_byte())
      if I32.band(offset, 0x2000) > 0, do: offset = I32.or(offset, 0xFFFFC000)
      @pc = @pc + offset - 2
    end
  end
end
