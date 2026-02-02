defmodule Zorb.Interpreter.Types do
  @moduledoc false

  defmodule ZChar do
    @moduledoc false
    @behaviour Orb.CustomType
    def wasm_type, do: :i32
  end

  defmodule ZWord do
    @moduledoc false
    @behaviour Orb.CustomType
    def wasm_type, do: :i32
  end

  defmodule Address do
    @moduledoc false
    @behaviour Orb.CustomType
    def wasm_type, do: :i32
  end

  defmodule PackedAddress do
    @moduledoc false
    @behaviour Orb.CustomType
    def wasm_type, do: :i32
  end

  defmodule Object do
    @moduledoc false
    @behaviour Orb.CustomType
    def wasm_type, do: :i32
  end

  defmodule Property do
    @moduledoc false
    @behaviour Orb.CustomType
    def wasm_type, do: :i32
  end

  defmodule Variable do
    @moduledoc false
    @behaviour Orb.CustomType
    def wasm_type, do: :i32
  end
end

defmodule Zorb.Interpreter.ZIO do
  @moduledoc false
  use Orb.Import, name: :zio
  defw(print_char(char: Orb.I32))
  defw(read_char(), Orb.I32)
  defw(get_random_seed(), Orb.I32)
  defw(get_capabilities(), Orb.I32)
  defw(halt(reason: Orb.I32, pc: Orb.I32, opcode: Orb.I32))
  defw(tokenize(text_addr: Orb.I32, parse_addr: Orb.I32, dict_addr: Orb.I32, flag: Orb.I32))
  defw(log_step(code: Orb.I32, val: Orb.I32))
end

defmodule Zorb.Interpreter do
  @moduledoc false
  use Orb
  alias Zorb.Interpreter.Types, as: T
  alias Zorb.Interpreter.ZIO

  Memory.pages(16)
  alias Orb.I32

  # Default Unicode Translation Table (Spec 3.8.5.2) - 97 characters for ZSCII 155-251
  @unicode_table [
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

  def unicode_table, do: @unicode_table

  global do
    @pc 0
    @version 0
    @sp 0
    @fp 0
    @csp 0
    @stack_base 0x90000
    @call_stack_base 0x98000
    @globals_base 0
    @static_memory_base 0
    @dictionary_base 0
    @object_table_base 0
    @object_table_start 0
    @abbreviations_base 0
    @next_alphabet -1
    @abbrev_mode 0
    @recursion_depth 0
    @packed_address_shift 0
    @routine_offset 0
    @string_offset 0
    @stream3_table 0
    @stream3_active 0
    @object_entry_size 0
    @object_parent_offset 0
    @object_sibling_offset 0
    @object_child_offset 0
    @object_property_table_offset 0
    @random_state 1
    @story_len 0
    @capabilities 0
    @zscii_state 0
    @zscii_high 0
    @unicode_table_base 0
    @current_font 1
    @current_alphabet 0
    @halted 0
  end

  Orb.Import.register(Zorb.Interpreter.ZIO)

  defw read_byte(addr: T.Address), I32 do
    Memory.load!(I32.U8, addr)
  end

  defw read_word(addr: T.Address), I32 do
    I32.or(I32.shl(Memory.load!(I32.U8, addr), 8), Memory.load!(I32.U8, I32.add(addr, 1)))
  end

  defw write_byte(addr: T.Address, val: I32) do
    if(I32.ge_u(addr, @static_memory_base),
      do: halt(4, @pc, 0),
      else: Memory.store!(I32.U8, addr, I32.band(val, 0xFF))
    )
  end

  defw write_word(addr: T.Address, val: I32) do
    if I32.ge_u(addr, @static_memory_base), do: return(halt(4, @pc, 0))
    Memory.store!(I32.U8, addr, I32.shr_u(val, 8))
    Memory.store!(I32.U8, I32.add(addr, 1), I32.band(val, 0xFF))
  end

  defw halt(reason: I32, pc: I32, opcode: I32) do
    @halted = I32.const(1)
    ZIO.halt(reason, pc, opcode)
  end

  defwp fetch_var_ref_operand(type: I32), I32 do
    if I32.eq(type, 0) do
      fetch_word()
    else
      if I32.eq(type, 1) do
        fetch_byte()
      else
        if I32.eq(type, 2) do
          read_variable(fetch_byte())
        else
          I32.const(0)
        end
      end
    end
  end

  # --- Variable Access (Spec 14.3) ---
  defw read_variable(var: T.Variable), I32 do
    if I32.eq(var, 0) do
      pop_stack()
    else
      if I32.lt_u(var, 16) do
        read_call_stack(I32.add(@fp, I32.add(4, I32.sub(var, 1))))
      else
        read_word(I32.add(@globals_base, I32.shl(I32.sub(var, 16), 1)))
      end
    end
  end

  defw read_variable_peek(var: T.Variable), I32 do
    if I32.eq(var, 0) do
      peek_stack()
    else
      if I32.lt_u(var, 16) do
        read_call_stack(I32.add(@fp, I32.add(4, I32.sub(var, 1))))
      else
        read_word(I32.add(@globals_base, I32.shl(I32.sub(var, 16), 1)))
      end
    end
  end

  defw write_variable(var: T.Variable, val: I32) do
    val = I32.band(val, 0xFFFF)

    if I32.eq(var, 0) do
      push_stack(val)
    else
      if I32.lt_u(var, 16) do
        write_call_stack(I32.add(@fp, I32.add(4, I32.sub(var, 1))), val)
      else
        write_word(I32.add(@globals_base, I32.shl(I32.sub(var, 16), 1)), val)
      end
    end
  end

  defw write_variable_replace(var: T.Variable, val: I32) do
    val = I32.band(val, 0xFFFF)

    if I32.eq(var, 0) do
      if I32.ne(@sp, 0) do
        write_stack(I32.sub(@sp, 1), val)
      else
        push_stack(val)
      end
    else
      if I32.lt_u(var, 16) do
        write_call_stack(I32.add(@fp, I32.add(4, I32.sub(var, 1))), val)
      else
        write_word(I32.add(@globals_base, I32.shl(I32.sub(var, 16), 1)), val)
      end
    end
  end

  defw push_stack(val: I32) do
    if(I32.ge_u(@sp, 1024), do: halt(1, @pc, 0))
    write_stack(@sp, val)
    @sp = I32.add(@sp, 1)
  end

  defw pop_stack(), I32 do
    if(I32.eq(@sp, 0), do: halt(2, @pc, 0))
    @sp = I32.sub(@sp, 1)
    read_stack(@sp)
  end

  defw peek_stack(), I32 do
    if(I32.eq(@sp, 0), do: halt(2, @pc, 0))
    read_stack(I32.sub(@sp, 1))
  end

  defw read_stack(idx: I32), I32 do
    read_word(I32.add(@stack_base, I32.shl(idx, 1)))
  end

  defw write_word_direct(addr: T.Address, val: I32) do
    Memory.store!(I32.U8, addr, I32.shr_u(val, 8))
    Memory.store!(I32.U8, I32.add(addr, 1), I32.band(val, 0xFF))
  end

  defw write_stack(idx: I32, val: I32) do
    write_word_direct(I32.add(@stack_base, I32.shl(idx, 1)), val)
  end

  defw push_call_stack(val: I32) do
    write_call_stack(@csp, val)
    @csp = I32.add(@csp, 1)
  end

  defw pop_call_stack(), I32 do
    @csp = I32.sub(@csp, 1)
    read_call_stack(@csp)
  end

  defw read_call_stack(idx: I32), I32 do
    read_word(I32.add(@call_stack_base, I32.shl(idx, 1)))
  end

  defw write_call_stack(idx: I32, val: I32) do
    write_word_direct(I32.add(@call_stack_base, I32.shl(idx, 1)), val)
  end

  # --- Fetching ---
  defw fetch_byte(), I32, val: I32 do
    val = read_byte(@pc)
    @pc = I32.add(@pc, 1)
    val
  end

  defw fetch_word(), I32, val: I32 do
    val = read_word(@pc)
    @pc = I32.add(@pc, 2)
    val
  end

  defwp fetch_operand(type: I32), I32 do
    if I32.eq(type, 0) do
      fetch_word()
    else
      if I32.eq(type, 1) do
        fetch_byte()
      else
        if I32.eq(type, 2) do
          read_variable(fetch_byte())
        else
          0
        end
      end
    end
  end

  defwp fetch_var_operand(type: I32), I32 do
    if I32.eq(type, 3) do
      0
    else
      fetch_operand(type)
    end
  end

  defwp fetch_raw_operand(type: I32), I32 do
    if I32.eq(type, 0) do
      fetch_word()
    else
      if I32.eq(type, 1) do
        fetch_byte()
      else
        if I32.eq(type, 2) do
          fetch_byte()
        else
          0
        end
      end
    end
  end

  defw execute_je(a: I32, b: I32, c: I32, d: I32, mask: I32), count: I32 do
    count = calculate_arg_count_generic(mask)

    if I32.ge_u(count, 2) do
      if I32.eq(a, b) do
        fetch_branch(1)
        return()
      end
    end

    if I32.ge_u(count, 3) do
      if I32.eq(a, c) do
        fetch_branch(1)
        return()
      end
    end

    if I32.ge_u(count, 4) do
      if I32.eq(a, d) do
        fetch_branch(1)
        return()
      end
    end

    fetch_branch(0)
  end

  # --- Opcodes ---
  defw execute_2op(opc: I32, o1: I32, o2: I32) do
    if I32.eq(opc, 0x01) do
      execute_je(o1, o2, 0, 0, 0x5F)
      return()
    end

    if I32.eq(opc, 0x02) do
      fetch_branch(I32.lt_s(sign_extend_16(o1), sign_extend_16(o2)))
      return()
    end

    if I32.eq(opc, 0x03) do
      fetch_branch(I32.gt_s(sign_extend_16(o1), sign_extend_16(o2)))
      return()
    end

    if I32.eq(opc, 0x04) do
      write_variable_replace(o1, I32.sub(read_variable_peek(o1), 1))
      fetch_branch(I32.lt_s(sign_extend_16(read_variable_peek(o1)), sign_extend_16(o2)))
      return()
    end

    if I32.eq(opc, 0x05) do
      write_variable_replace(o1, I32.add(read_variable_peek(o1), 1))
      fetch_branch(I32.gt_s(sign_extend_16(read_variable_peek(o1)), sign_extend_16(o2)))
      return()
    end

    if I32.eq(opc, 0x06) do
      fetch_branch(I32.eq(get_object_parent(o1), o2))
      return()
    end

    if I32.eq(opc, 0x07) do
      # test bitmap flags
      fetch_branch(I32.eq(I32.band(o1, o2), o2))
      return()
    end

    if I32.eq(opc, 0x08) do
      fetch_result_and_store(I32.band(I32.or(o1, o2), 0xFFFF))
      return()
    end

    if I32.eq(opc, 0x09) do
      fetch_result_and_store(I32.band(I32.band(o1, o2), 0xFFFF))
      return()
    end

    if I32.eq(opc, 0x0A) do
      fetch_branch(check_attribute(o1, o2))
      return()
    end

    if I32.eq(opc, 0x0B) do
      set_attribute(o1, o2, 1)
      return()
    end

    if I32.eq(opc, 0x0C) do
      set_attribute(o1, o2, 0)
      return()
    end

    if I32.eq(opc, 0x0D) do
      write_variable_replace(o1, o2)
      return()
    end

    if I32.eq(opc, 0x0E) do
      do_insert_obj(o1, o2)
      return()
    end

    if I32.eq(opc, 0x0F) do
      fetch_result_and_store(read_word(I32.add(o1, I32.shl(o2, 1))))
      return()
    end

    if I32.eq(opc, 0x10) do
      fetch_result_and_store(read_byte(I32.add(o1, o2)))
      return()
    end

    if I32.eq(opc, 0x11) do
      fetch_result_and_store(get_prop_value(o1, o2))
      return()
    end

    if I32.eq(opc, 0x12) do
      fetch_result_and_store(get_prop_address(o1, o2))
      return()
    end

    if I32.eq(opc, 0x13) do
      fetch_result_and_store(get_next_prop(o1, o2))
      return()
    end

    if I32.eq(opc, 0x14) do
      fetch_result_and_store(I32.band(I32.add(o1, o2), 0xFFFF))
      return()
    end

    if I32.eq(opc, 0x15) do
      fetch_result_and_store(I32.band(I32.sub(o1, o2), 0xFFFF))
      return()
    end

    if I32.eq(opc, 0x16) do
      fetch_result_and_store(I32.band(I32.mul(o1, o2), 0xFFFF))
      return()
    end

    if I32.eq(opc, 0x17) do
      fetch_result_and_store(I32.band(I32.div_s(sign_extend_16(o1), sign_extend_16(o2)), 0xFFFF))
      return()
    end

    if I32.eq(opc, 0x18) do
      fetch_result_and_store(I32.band(I32.rem_s(sign_extend_16(o1), sign_extend_16(o2)), 0xFFFF))
      return()
    end

    if I32.eq(opc, 0x19) do
      # call_2s
      do_call(unpack_routine_address(o1), fetch_byte(), 1, o2, 0, 0, 0, 0, 0, 0, 0)
      return()
    end

    if I32.eq(opc, 0x1A) do
      # call_2n
      do_call(unpack_routine_address(o1), 0xFF, 1, o2, 0, 0, 0, 0, 0, 0, 0)
      return()
    end

    if I32.eq(opc, 0x1C) do
      # throw (V5)
      # return val to frame index
      @csp = o2
      do_return(o1)
      return()
    end

    halt(3, @pc, opc)
  end

  defw execute_1op(opc: I32, o1: I32) do
    if I32.eq(opc, 0x00) do
      fetch_branch(I32.eq(o1, 0))
      return()
    end

    if I32.eq(opc, 0x01) do
      do_get_sibling(o1)
      return()
    end

    if I32.eq(opc, 0x02) do
      do_get_child(o1)
      return()
    end

    if I32.eq(opc, 0x03) do
      fetch_result_and_store(get_object_parent(o1))
      return()
    end

    if I32.eq(opc, 0x04) do
      fetch_result_and_store(get_prop_len(o1))
      return()
    end

    if I32.eq(opc, 0x05) do
      write_variable_replace(o1, I32.add(read_variable_peek(o1), 1))
      return()
    end

    if I32.eq(opc, 0x06) do
      write_variable_replace(o1, I32.sub(read_variable_peek(o1), 1))
      return()
    end

    if I32.eq(opc, 0x07) do
      print_zstring(o1)
      return()
    end

    if I32.eq(opc, 0x08) do
      do_call(unpack_routine_address(o1), fetch_byte(), 0, 0, 0, 0, 0, 0, 0, 0, 0)
      return()
    end

    if I32.eq(opc, 0x09) do
      do_remove_obj(o1)
      return()
    end

    if I32.eq(opc, 0x0A) do
      # print_obj
      print_zstring(I32.add(get_prop_table_address(o1), 1))
      return()
    end

    if I32.eq(opc, 0x0B) do
      do_return(o1)
      return()
    end

    if I32.eq(opc, 0x0C) do
      @pc = I32.add(I32.add(@pc, sign_extend_16(o1)), -2)
      return()
    end

    if I32.eq(opc, 0x0D) do
      print_zstring(unpack_string_address(o1))
      return()
    end

    if I32.eq(opc, 0x0E) do
      fetch_result_and_store(read_variable_peek(o1))
      return()
    end

    if I32.eq(opc, 0x0F) do
      if I32.lt_u(@version, 5) do
        # not
        fetch_result_and_store(I32.band(I32.xor(o1, 0xFFFF), 0xFFFF))
      else
        # call_1n
        do_call(unpack_routine_address(o1), 0xFF, 0, 0, 0, 0, 0, 0, 0, 0, 0)
      end

      return()
    end

    halt(3, @pc, opc)
  end

  defw execute_0op(opc: I32) do
    if I32.eq(opc, 0x00) do
      do_return(1)
      return()
    end

    if I32.eq(opc, 0x01) do
      do_return(0)
      return()
    end

    if I32.eq(opc, 0x02) do
      print_zstring(0)
      return()
    end

    if I32.eq(opc, 0x03) do
      print_zstring(0)
      print_char_wasm(13)
      do_return(1)
      return()
    end

    if I32.eq(opc, 0x08) do
      do_return(pop_stack())
      return()
    end

    if I32.eq(opc, 0x09) do
      # catch (V5)
      fetch_result_and_store(@csp)
      return()
    end

    if I32.eq(opc, 0x0A) do
      halt(0, @pc, 0)
      return()
    end

    if I32.eq(opc, 0x0B) do
      print_char_wasm(13)
      return()
    end

    if I32.eq(opc, 0x0C) do
      # show_status (V3)
      return()
    end

    if I32.eq(opc, 0x0D) do
      fetch_branch(do_verify())
      return()
    end

    if I32.eq(opc, 0x0F) do
      # piracy (V5)
      fetch_branch(1)
      return()
    end

    halt(3, @pc, opc)
  end

  defw execute_var(
         opc: I32,
         mask: I32,
         t2: I32,
         o1: I32,
         o2: I32,
         o3: I32,
         o4: I32,
         o5: I32,
         o6: I32,
         o7: I32,
         o8: I32
       ),
       val: I32 do
    if I32.eq(opc, 0x1F) do
      # check_arg_count
      if I32.eq(o1, 0) do
        fetch_branch(1)
      else
        # Read count directly from stack (bits 8-15 of word at FP + 2)
        val = I32.shr_u(read_call_stack(I32.add(@fp, 2)), 8)
        fetch_branch(I32.ge_u(val, o1))
      end

      return()
    end

    if I32.eq(opc, 0x00) do
      # call_vs
      do_call(
        unpack_routine_address(o1),
        fetch_byte(),
        calculate_arg_count2(mask, t2),
        o2,
        o3,
        o4,
        o5,
        o6,
        o7,
        o8,
        0
      )

      return()
    end

    if I32.eq(opc, 0x01) do
      write_word(I32.add(o1, I32.shl(o2, 1)), o3)
      return()
    end

    if I32.eq(opc, 0x02) do
      write_byte(I32.add(o1, o2), o3)
      return()
    end

    if I32.eq(opc, 0x03) do
      put_prop_value(o1, o2, o3)
      return()
    end

    if I32.eq(opc, 0x04) do
      val = read_input(o1)

      if I32.band(mask, 2) do
        do_tokenise(o1, o2, 0)
      end

      if I32.ge_u(@version, 5) do
        fetch_result_and_store(val)
      end

      return()
    end

    if I32.eq(opc, 0x05) do
      print_char_wasm(zscii_to_unicode(o1))
      return()
    end

    if I32.eq(opc, 0x06) do
      print_number(sign_extend_16(o1))
      return()
    end

    if I32.eq(opc, 0x07) do
      fetch_result_and_store(do_random(sign_extend_16(o1)))
      return()
    end

    if I32.eq(opc, 0x08) do
      push_stack(o1)
      return()
    end

    if I32.eq(opc, 0x09) do
      # pull
      write_variable_replace(o1, pop_stack())
      return()
    end

    if I32.eq(opc, 0x0A) do
      # split_window
      return()
    end

    if I32.eq(opc, 0x0B) do
      # set_window
      return()
    end

    if I32.eq(opc, 0x0C) do
      # call_vs2
      do_call(
        unpack_routine_address(o1),
        fetch_byte(),
        calculate_arg_count2(mask, t2),
        o2,
        o3,
        o4,
        o5,
        o6,
        o7,
        o8,
        0
      )

      return()
    end

    if I32.eq(opc, 0x0D) do
      # erase_window
      return()
    end

    if I32.eq(opc, 0x11) do
      # set_text_style
      return()
    end

    if I32.eq(opc, 0x13) do
      # output_stream
      do_output_stream(sign_extend_16(o1), o2)
      return()
    end

    if I32.eq(opc, 0x16) do
      fetch_result_and_store(unicode_to_zscii(ZIO.read_char()))
      return()
    end

    if I32.eq(opc, 0x17) do
      fetch_result_and_store(do_scan_table(o1, o2, o3, o4))
      return()
    end

    if I32.eq(opc, 0x18) do
      # not
      fetch_result_and_store(I32.band(I32.xor(o1, 0xFFFF), 0xFFFF))
      return()
    end

    if I32.eq(opc, 0x19) do
      # call_vn
      do_call(
        unpack_routine_address(o1),
        0xFF,
        calculate_arg_count2(mask, t2),
        o2,
        o3,
        o4,
        o5,
        o6,
        o7,
        o8,
        0
      )

      return()
    end

    if I32.eq(opc, 0x1A) do
      # call_vn2
      do_call(
        unpack_routine_address(o1),
        0xFF,
        calculate_arg_count2(mask, t2),
        o2,
        o3,
        o4,
        o5,
        o6,
        o7,
        o8,
        0
      )

      return()
    end

    if I32.eq(opc, 0x1B) do
      # tokenize
      do_tokenise(o1, o2, o3)
      return()
    end

    if I32.eq(opc, 0x1D) do
      # copy_table
      do_copy_table(o1, o2, sign_extend_16(o3))
      return()
    end

    if I32.eq(opc, 0x1E) do
      # print_table
      do_print_table(o1, o2, o3, o4)
      return()
    end

    halt(3, @pc, opc)
  end

  defw execute_ext(opc: I32, o1: I32, o2: I32, o3: I32, o4: I32) do
    if I32.eq(opc, 0x00) do
      # save (V5)
      fetch_result_and_store(0)
      return()
    end

    if I32.eq(opc, 0x01) do
      # restore (V5)
      fetch_result_and_store(0)
      return()
    end

    if I32.eq(opc, 0x02) do
      if I32.gt_s(sign_extend_16(o2), 0) do
        fetch_result_and_store(I32.shl(o1, sign_extend_16(o2)))
      else
        fetch_result_and_store(I32.shr_u(I32.band(o1, 0xFFFF), I32.sub(0, sign_extend_16(o2))))
      end

      return()
    end

    if I32.eq(opc, 0x03) do
      if I32.gt_s(sign_extend_16(o2), 0) do
        fetch_result_and_store(I32.shl(o1, sign_extend_16(o2)))
      else
        fetch_result_and_store(I32.shr_s(sign_extend_16(o1), I32.sub(0, sign_extend_16(o2))))
      end

      return()
    end

    if I32.eq(opc, 0x04) do
      do_set_font(o1)
      return()
    end

    if I32.eq(opc, 0x0B) do
      print_char_wasm(o1)
      return()
    end

    if I32.eq(opc, 0x0C) do
      # check_unicode
      fetch_result_and_store(3)
      return()
    end

    if I32.eq(opc, 0x1B) do
      # set_unicode_table
      @unicode_table_base = o1
      return()
    end
  end

  # --- Objects Helpers ---
  defw get_object_address(obj: T.Object), T.Address do
    if(I32.eq(obj, 0),
      do: I32.const(0),
      else: I32.add(@object_table_start, I32.mul(I32.sub(obj, 1), @object_entry_size))
    )
  end

  defw get_object_parent(obj: T.Object), T.Object do
    if(I32.eq(obj, 0), do: return(0))

    if(I32.le_u(@version, 3),
      do: read_byte(I32.add(get_object_address(obj), @object_parent_offset)),
      else: read_word(I32.add(get_object_address(obj), @object_parent_offset))
    )
  end

  defw get_object_sibling(obj: T.Object), T.Object do
    if(I32.eq(obj, 0), do: return(0))

    if(I32.le_u(@version, 3),
      do: read_byte(I32.add(get_object_address(obj), @object_sibling_offset)),
      else: read_word(I32.add(get_object_address(obj), @object_sibling_offset))
    )
  end

  defw get_object_child(obj: T.Object), T.Object do
    if(I32.eq(obj, 0), do: return(0))

    if(I32.le_u(@version, 3),
      do: read_byte(I32.add(get_object_address(obj), @object_child_offset)),
      else: read_word(I32.add(get_object_address(obj), @object_child_offset))
    )
  end

  defw set_object_parent(obj: T.Object, parent: T.Object) do
    if(I32.le_u(@version, 3),
      do: write_byte(I32.add(get_object_address(obj), @object_parent_offset), parent),
      else: write_word(I32.add(get_object_address(obj), @object_parent_offset), parent)
    )
  end

  defw set_object_sibling(obj: T.Object, sib: T.Object) do
    if(I32.le_u(@version, 3),
      do: write_byte(I32.add(get_object_address(obj), @object_sibling_offset), sib),
      else: write_word(I32.add(get_object_address(obj), @object_sibling_offset), sib)
    )
  end

  defw set_object_child(obj: T.Object, child: T.Object) do
    if(I32.le_u(@version, 3),
      do: write_byte(I32.add(get_object_address(obj), @object_child_offset), child),
      else: write_word(I32.add(get_object_address(obj), @object_child_offset), child)
    )
  end

  defw get_prop_table_address(obj: T.Object), T.Address do
    read_word(I32.add(get_object_address(obj), @object_property_table_offset))
  end

  defw remove_from_siblings(obj: T.Object, parent: T.Object), prev: T.Object, curr: T.Object do
    curr = get_object_child(parent)

    if I32.eq(curr, obj) do
      set_object_child(parent, get_object_sibling(obj))
    else
      Control.block SibLoopBlock do
        loop SibLoop do
          prev = curr
          curr = get_object_sibling(curr)

          if I32.eq(curr, obj) do
            set_object_sibling(prev, get_object_sibling(obj))
            SibLoopBlock.break()
          end

          if I32.eq(curr, 0) do
            SibLoopBlock.break()
          end

          SibLoop.continue()
        end
      end
    end
  end

  defw add_to_children(obj: T.Object, parent: T.Object) do
    set_object_sibling(obj, get_object_child(parent))
    set_object_child(parent, obj)
  end

  # --- Properties Helpers ---
  defwp get_prop_num(addr: T.Address), I32, b: I32 do
    b = read_byte(addr)
    if(I32.le_u(@version, 3), do: I32.band(b, 31), else: I32.band(b, 63))
  end

  defwp get_prop_header_size(header_addr: T.Address), I32, b: I32 do
    if I32.le_u(@version, I32.const(3)) do
      I32.const(1)
    else
      b = read_byte(header_addr)
      if I32.band(b, 128), do: I32.const(2), else: I32.const(1)
    end
  end

  defwp get_prop_data_size(header_addr: T.Address), I32, b: I32 do
    b = read_byte(header_addr)

    if I32.le_u(@version, 3) do
      I32.add(I32.shr_u(b, 5), 1)
    else
      if I32.band(b, 128) do
        # 2-byte header, size is in bits 0-5 of second byte.
        b = I32.band(read_byte(I32.add(header_addr, 1)), 63)
        if I32.eq(b, 0), do: I32.const(64), else: b
      else
        # 1-byte header, bit 6 is size (0=1, 1=2).
        if I32.band(b, 64), do: I32.const(2), else: I32.const(1)
      end
    end
  end

  defw get_zstring_byte_length(addr: T.Address), I32, word: I32 do
    loop ZLoop do
      word = read_word(addr)
      addr = I32.add(addr, 2)
      ZLoop.continue(if: I32.eq(I32.band(word, 0x8000), 0))
    end

    addr
  end

  defwp skip_name(name_addr: T.Address), T.Address do
    if I32.eq(read_byte(I32.sub(name_addr, 1)), 0) do
      # If length byte is 0, name is empty
      return(name_addr)
    end

    # Bit-accurate scanning (Spec 3.2.1)
    get_zstring_byte_length(name_addr)
  end

  defw get_prop_header_address(obj: T.Object, prop: T.Property), T.Address, addr: T.Address do
    addr = skip_name(I32.add(get_prop_table_address(obj), 1))

    loop PropLoop do
      if(I32.eq(read_byte(addr), 0), do: return(0))

      if I32.eq(get_prop_num(addr), prop) do
        return(addr)
      end

      addr = I32.add(addr, I32.add(get_prop_header_size(addr), get_prop_data_size(addr)))
      PropLoop.continue()
    end

    0
  end

  defw get_prop_address(obj: T.Object, prop: T.Property), T.Address, addr: T.Address do
    addr = get_prop_header_address(obj, prop)

    if I32.eq(addr, 0) do
      I32.const(0)
    else
      I32.add(addr, get_prop_header_size(addr))
    end
  end

  defw get_prop_value(obj: T.Object, prop: T.Property), I32, addr: T.Address do
    addr = get_prop_header_address(obj, prop)

    if(I32.eq(addr, 0),
      do: return(read_word(I32.add(@object_table_base, I32.shl(I32.sub(prop, 1), 1))))
    )

    if I32.eq(get_prop_data_size(addr), 1) do
      read_byte(I32.add(addr, get_prop_header_size(addr)))
    else
      read_word(I32.add(addr, get_prop_header_size(addr)))
    end
  end

  defw put_prop_value(obj: T.Object, prop: T.Property, val: I32), addr: T.Address do
    addr = get_prop_header_address(obj, prop)
    if(I32.eq(addr, 0), do: return())

    if I32.eq(get_prop_data_size(addr), 1) do
      write_byte(I32.add(addr, get_prop_header_size(addr)), val)
    else
      write_word(I32.add(addr, get_prop_header_size(addr)), val)
    end
  end

  defw get_next_prop(obj: T.Object, prop: T.Property), I32, addr: T.Address do
    if I32.eq(prop, 0) do
      addr = skip_name(I32.add(get_prop_table_address(obj), 1))
      return(get_prop_num(addr))
    end

    addr = get_prop_header_address(obj, prop)
    if(I32.eq(addr, 0), do: return(0))
    # Move to next header
    addr = I32.add(addr, I32.add(get_prop_header_size(addr), get_prop_data_size(addr)))
    get_prop_num(addr)
  end

  defw get_prop_len(data_addr: T.Address), I32, b: I32 do
    if I32.eq(data_addr, 0), do: return(0)

    # Working backward from data address is still needed for get_prop_len opcode
    # because it ONLY receives the data address.
    b = read_byte(I32.sub(data_addr, 1))

    if I32.le_u(@version, 3), do: return(I32.add(I32.shr_u(b, 5), 1))

    # V4+ logic from Spec 12.4.3
    if I32.band(b, 128) do
      b = I32.band(b, 63)
      if I32.eq(b, 0), do: I32.const(64), else: b
    else
      if I32.band(b, 64), do: I32.const(2), else: I32.const(1)
    end
  end

  defw print_char_wasm(char: I32), len: I32 do
    if @stream3_active do
      len = read_word(@stream3_table)
      write_byte(I32.add(@stream3_table, I32.add(2, len)), char)
      write_word_direct(@stream3_table, I32.add(len, 1))
      return()
    end

    ZIO.print_char(char)
  end

  defw do_output_stream(s: I32, addr: T.Address) do
    if I32.eq(s, 3) do
      @stream3_table = addr
      @stream3_active = 1
    end

    if I32.eq(s, -3) do
      @stream3_active = 0
    end
  end

  # --- Attributes Helpers ---
  defw check_attribute(obj: T.Object, attr: I32), I32 do
    if(I32.eq(obj, 0), do: return(0))

    I32.band(
      read_byte(I32.add(get_object_address(obj), I32.shr_u(attr, 3))),
      I32.shl(1, I32.sub(7, I32.band(attr, 7)))
    )
  end

  defw set_attribute(obj: T.Object, attr: I32, val: I32), addr: T.Address, b: I32 do
    if(I32.eq(obj, 0), do: return())

    addr = I32.add(get_object_address(obj), I32.shr_u(attr, 3))
    b = read_byte(addr)

    b =
      if(val,
        do: I32.or(b, I32.shl(1, I32.sub(7, I32.band(attr, 7)))),
        else: I32.band(b, I32.xor(I32.shl(1, I32.sub(7, I32.band(attr, 7))), 0xFF))
      )

    write_byte(addr, b)
  end

  # --- Unicode ---
  defw zscii_to_unicode(char: I32), I32, num: I32 do
    if I32.eq(@current_font, 3) do
      # Box Drawings
      # │
      if I32.eq(char, 33), do: return(0x2502)
      # ─
      if I32.eq(char, 34), do: return(0x2500)
      # ┌
      if I32.eq(char, 35), do: return(0x250C)
      # ┐
      if I32.eq(char, 36), do: return(0x2510)
      # └
      if I32.eq(char, 37), do: return(0x2514)
      # ┘
      if I32.eq(char, 38), do: return(0x2518)
      # ├
      if I32.eq(char, 39), do: return(0x251C)
      # ┤
      if I32.eq(char, 40), do: return(0x2524)
      # ┬
      if I32.eq(char, 41), do: return(0x252C)
      # ┴
      if I32.eq(char, 42), do: return(0x2534)
      # ┼
      if I32.eq(char, 43), do: return(0x253C)

      # Arrows
      # ↑
      if I32.eq(char, 44), do: return(0x2191)
      # ↓
      if I32.eq(char, 45), do: return(0x2193)
      # ←
      if I32.eq(char, 46), do: return(0x2190)
      # →
      if I32.eq(char, 47), do: return(0x2192)

      # Runes (Anglian Futhorc)
      # a ᚪ
      if I32.eq(char, 97), do: return(0x16AA)
      # b ᛒ
      if I32.eq(char, 98), do: return(0x16D2)
      # c (eo) ᛇ
      if I32.eq(char, 99), do: return(0x16C7)
      # d ᛞ
      if I32.eq(char, 100), do: return(0x16DE)
      # e ᛖ
      if I32.eq(char, 101), do: return(0x16D6)
      # f ᚠ
      if I32.eq(char, 102), do: return(0x16A0)
      # g ᚷ
      if I32.eq(char, 103), do: return(0x16B7)
      # h ᚻ
      if I32.eq(char, 104), do: return(0x16BB)
      # i ᛁ
      if I32.eq(char, 105), do: return(0x16C1)
      # j ᛄ
      if I32.eq(char, 106), do: return(0x16C4)
      # k (other k) ᛢ
      if I32.eq(char, 107), do: return(0x16E2)
      # l ᛚ
      if I32.eq(char, 108), do: return(0x16DA)
      # m ᛗ
      if I32.eq(char, 109), do: return(0x16D7)
      # n ᚾ
      if I32.eq(char, 110), do: return(0x16BE)
      # o ᚩ
      if I32.eq(char, 111), do: return(0x16A9)
      # p ᛈ
      if I32.eq(char, 112), do: return(0x16C8)
      # q (k) ᚳ
      if I32.eq(char, 113), do: return(0x16B3)
      # r ᚱ
      if I32.eq(char, 114), do: return(0x16B1)
      # s ᛋ
      if I32.eq(char, 115), do: return(0x16CB)
      # t ᛏ
      if I32.eq(char, 116), do: return(0x16CF)
      # u ᚢ
      if I32.eq(char, 117), do: return(0x16A2)
      # v (ea) ᛪ
      if I32.eq(char, 118), do: return(0x16EA)
      # w ᚹ
      if I32.eq(char, 119), do: return(0x16B9)
      # x (z) ᛉ
      if I32.eq(char, 120), do: return(0x16C9)
      # y ᚣ
      if I32.eq(char, 121), do: return(0x16A3)
      # z (oe) ᛟ
      if I32.eq(char, 122), do: return(0x16DF)
    end

    if(I32.lt_u(char, 155), do: return(char))
    if(I32.gt_u(char, 251), do: return(63))

    if I32.ne(@unicode_table_base, 0) do
      num = read_byte(@unicode_table_base)

      if I32.lt_u(I32.sub(char, 155), num) do
        return(
          read_word(I32.add(@unicode_table_base, I32.add(1, I32.shl(I32.sub(char, 155), 1))))
        )
      end

      return(63)
    end

    if(I32.lt_u(I32.sub(char, 155), 97),
      do: return(read_word(I32.add(0x80000, I32.shl(I32.sub(char, 155), 1))))
    )

    63
  end

  defw unicode_to_zscii(uni: I32), I32, num: I32, i: I32, val: I32 do
    if(I32.lt_u(uni, 155), do: return(uni))

    if I32.ne(@unicode_table_base, 0) do
      num = read_byte(@unicode_table_base)
      i = 0

      loop CSearch do
        if I32.lt_u(i, num) do
          val = read_word(I32.add(@unicode_table_base, I32.add(1, I32.shl(i, 1))))

          if I32.eq(val, uni) do
            return(I32.add(i, 155))
          end

          i = I32.add(i, 1)
          CSearch.continue()
        end
      end
    end

    i = 0

    loop DSearch do
      if I32.lt_u(i, 97) do
        val = read_word(I32.add(0x80000, I32.shl(i, 1)))

        if I32.eq(val, uni) do
          return(I32.add(i, 155))
        end

        i = I32.add(i, 1)
        DSearch.continue()
      end
    end

    63
  end

  defw drop_i32(v: I32) do
  end

  # --- Alphabet/Strings ---
  defw print_number(val: I32) do
    if I32.eq(val, 0) do
      print_char_wasm(48)
      return()
    end

    if I32.lt_s(val, 0) do
      print_char_wasm(45)
      val = I32.sub(0, val)
    end

    print_number_recur(val)
  end

  defw print_number_recur(val: I32) do
    if I32.gt_s(val, 0) do
      print_number_recur(I32.div_s(val, 10))
      print_char_wasm(I32.add(I32.rem_s(val, 10), 48))
    end
  end

  defw decode_zchar(zchar: T.ZChar), alph: I32, pbase: I32, old_pc: T.Address do
    if(I32.eq(@zscii_state, 1),
      do:
        (
          @zscii_high = zchar
          @zscii_state = 2
          @next_alphabet = -1
          return()
        )
    )

    if(I32.eq(@zscii_state, 2),
      do:
        (
          print_char_wasm(zscii_to_unicode(I32.or(I32.shl(@zscii_high, 5), zchar)))
          @zscii_state = 0
          @next_alphabet = -1
          return()
        )
    )

    # Abbreviations
    if I32.gt_u(@abbrev_mode, 0) do
      old_pc = @pc

      @pc =
        I32.shl(
          read_word(
            I32.add(
              @abbreviations_base,
              I32.shl(I32.add(I32.shl(I32.sub(@abbrev_mode, 1), 5), zchar), 1)
            )
          ),
          1
        )

      @abbrev_mode = 0
      @next_alphabet = -1
      print_zstring(@pc)
      @pc = old_pc
      return()
    end

    if(I32.eq(zchar, 0),
      do:
        (
          print_char_wasm(32)
          @next_alphabet = -1
          return()
        )
    )

    # V1 Newline
    if I32.eq(@version, 1) do
      if I32.eq(zchar, 1) do
        print_char_wasm(13)
        return()
      end
    end

    # V2+ Abbreviation markers (Spec 3.3)
    if I32.ge_u(@version, 2) do
      # V2 uses only char 1 (bank 0)
      if I32.eq(zchar, 1) do
        @abbrev_mode = 1
        @next_alphabet = -1
        return()
      end

      # V3+ uses chars 1, 2, 3 (banks 0, 1, 2)
      if I32.ge_u(@version, 3) do
        if I32.or(I32.eq(zchar, 2), I32.eq(zchar, 3)) do
          @abbrev_mode = zchar
          @next_alphabet = -1
          return()
        end
      end
    end

    # Shift characters
    if I32.le_u(@version, 2) do
      # V1/V2 relative shift/lock rules (Spec 3.2.2)
      if I32.eq(zchar, 2) do
        # next = (curr + 1) % 3
        @next_alphabet = I32.rem_u(I32.add(@current_alphabet, 1), 3)
        return()
      end

      if I32.eq(zchar, 3) do
        # next = (curr - 1) % 3 -> (curr + 2) % 3
        @next_alphabet = I32.rem_u(I32.add(@current_alphabet, 2), 3)
        return()
      end

      if I32.eq(zchar, 4) do
        # lock = (curr + 1) % 3
        @current_alphabet = I32.rem_u(I32.add(@current_alphabet, 1), 3)
        @next_alphabet = -1
        return()
      end

      if I32.eq(zchar, 5) do
        # lock = (curr + 2) % 3
        @current_alphabet = I32.rem_u(I32.add(@current_alphabet, 2), 3)
        @next_alphabet = -1
        return()
      end
    else
      # V3+ shift rules (Spec 3.2.3)
      if I32.eq(zchar, 2) do
        @abbrev_mode = 2
        return()
      end

      if I32.eq(zchar, 3) do
        @abbrev_mode = 3
        return()
      end

      if I32.eq(zchar, 4) do
        @next_alphabet = 1
        return()
      end

      if I32.eq(zchar, 5) do
        @next_alphabet = 2
        return()
      end
    end

    # Determine alphabet
    alph = if(I32.ne(@next_alphabet, -1), do: @next_alphabet, else: @current_alphabet)

    if I32.eq(alph, 2) do
      if I32.ge_u(@version, 2) do
        if I32.eq(zchar, 6) do
          @zscii_state = 1
          @next_alphabet = -1
          return()
        end
      end
    end

    # This is the core fix: use pbase for offset calculation
    pbase = I32.const(6)

    if I32.ge_u(zchar, pbase) do
      print_char_wasm(
        zscii_to_unicode(
          read_byte(
            I32.add(
              0x81000,
              I32.add(I32.mul(alph, 26), I32.sub(zchar, pbase))
            )
          )
        )
      )

      @next_alphabet = -1
    end
  end

  defw print_zstring(addr: T.Address), word: I32, done: I32, s_sh: I32, s_curr: I32 do
    s_sh = @next_alphabet
    s_curr = @current_alphabet
    @next_alphabet = -1
    @current_alphabet = 0
    @abbrev_mode = 0

    if I32.ne(addr, 0) do
      loop ALoop do
        word = read_word(addr)
        addr = I32.add(addr, 2)
        done = I32.band(word, 0x8000)
        decode_zchar(I32.band(I32.shr_u(word, 10), 31))
        decode_zchar(I32.band(I32.shr_u(word, 5), 31))
        decode_zchar(I32.band(word, 31))
        ALoop.continue(if: I32.eq(done, 0))
      end

      @next_alphabet = s_sh
      @current_alphabet = s_curr
      return()
    end

    @recursion_depth = I32.add(@recursion_depth, I32.const(1))

    if(I32.gt_u(@recursion_depth, I32.const(2)),
      do:
        (
          @next_alphabet = s_sh
          @recursion_depth = I32.sub(@recursion_depth, I32.const(1))
          return()
        )
    )

    loop DLoop do
      word = fetch_word()
      done = I32.band(word, I32.const(0x8000))
      decode_zchar(I32.band(I32.shr_u(word, I32.const(10)), I32.const(31)))
      decode_zchar(I32.band(I32.shr_u(word, I32.const(5)), I32.const(31)))
      decode_zchar(I32.band(word, I32.const(31)))
      DLoop.continue(if: I32.eq(done, I32.const(0)))
    end

    @next_alphabet = s_sh
    @abbrev_mode = I32.const(0)
    @recursion_depth = I32.sub(@recursion_depth, I32.const(1))
  end

  defw do_verify(), I32 do
    # For now, just return 1
    I32.const(1)
  end

  defw do_scan_table(x: I32, tab: T.Address, len: I32, form: I32), T.Address,
    i: I32,
    wf: I32,
    step: I32,
    val: I32 do
    wf = I32.band(form, 0x80)
    step = I32.band(form, 0x7F)
    if(I32.eq(step, 0), do: step = if(wf, do: I32.const(2), else: I32.const(1)))
    i = 0

    loop SLoop do
      if I32.lt_u(i, len) do
        val =
          if(wf,
            do: read_word(I32.add(tab, I32.mul(i, step))),
            else: read_byte(I32.add(tab, I32.mul(i, step)))
          )

        if(I32.eq(val, x), do: return(I32.add(tab, I32.mul(i, step))))
        i = I32.add(i, 1)
        SLoop.continue()
      end
    end

    I32.const(0)
  end

  defw do_random(range: I32), I32, val: I32 do
    if(I32.le_s(range, 0),
      do:
        (
          @random_state = 1
          return(0)
        )
    )

    @random_state = I32.add(I32.mul(@random_state, 1_103_515_245), 12_345)
    val = I32.band(I32.shr_u(@random_state, 16), 0x7FFF)
    I32.add(I32.rem_u(val, range), 1)
  end

  defw sign_extend_16(v: I32), I32 do
    if(I32.band(v, 0x8000), do: return(I32.or(v, 0xFFFF0000)))
    v
  end

  defw set_font(f: I32), I32, old: I32 do
    old = @current_font
    @current_font = f
    old
  end

  defw fetch_result_and_store(v: I32) do
    write_variable(fetch_byte(), v)
  end

  defw fetch_result_and_store_replace(v: I32) do
    write_variable_replace(fetch_byte(), v)
  end

  defw extend_14(v: I32), I32 do
    if I32.band(v, 0x2000), do: I32.or(v, 0xFFFFC000), else: v
  end

  defw fetch_branch(cond: I32), b: I32, off: I32, ji: I32, take: I32 do
    b = fetch_byte()
    ji = I32.shr_u(b, 7)

    off =
      if I32.ne(I32.band(b, 0x40), 0) do
        I32.band(b, 0x3F)
      else
        # Long branch
        extend_14(I32.or(I32.shl(I32.band(b, 0x3F), 8), fetch_byte()))
      end

    take = if I32.ne(cond, 0), do: I32.const(1), else: I32.const(0)

    if I32.eq(ji, take) do
      if I32.eq(off, 0) do
        do_return(0)
      else
        if I32.eq(off, 1) do
          do_return(1)
        else
          @pc = I32.add(I32.add(@pc, off), -2)
        end
      end
    end
  end

  defwp calculate_arg_count_generic(mask: I32), I32, c: I32 do
    c = 0
    if I32.ne(I32.band(I32.shr_u(mask, 6), 3), 3), do: c = I32.add(c, 1)
    if I32.ne(I32.band(I32.shr_u(mask, 4), 3), 3), do: c = I32.add(c, 1)
    if I32.ne(I32.band(I32.shr_u(mask, 2), 3), 3), do: c = I32.add(c, 1)
    if I32.ne(I32.band(mask, 3), 3), do: c = I32.add(c, 1)
    c
  end

  defwp calculate_arg_count(mask: I32), I32, c: I32 do
    c = 0
    # Bits 5:4 (Arg 1)
    if I32.ne(I32.band(I32.shr_u(mask, 4), 3), 3), do: c = I32.add(c, 1)
    # Bits 3:2 (Arg 2)
    if I32.ne(I32.band(I32.shr_u(mask, 2), 3), 3), do: c = I32.add(c, 1)
    # Bits 1:0 (Arg 3)
    if I32.ne(I32.band(mask, 3), 3), do: c = I32.add(c, 1)
    c
  end

  defwp calculate_arg_count2(m1: I32, m2: I32), I32, c: I32 do
    c = calculate_arg_count(m1)
    # m2: Args 4-7
    if I32.ne(I32.band(I32.shr_u(m2, 6), 3), 3), do: c = I32.add(c, 1)
    if I32.ne(I32.band(I32.shr_u(m2, 4), 3), 3), do: c = I32.add(c, 1)
    if I32.ne(I32.band(I32.shr_u(m2, 2), 3), 3), do: c = I32.add(c, 1)
    if I32.ne(I32.band(m2, 3), 3), do: c = I32.add(c, 1)
    c
  end

  defw do_call(
         addr: T.PackedAddress,
         res: T.Variable,
         count: I32,
         a1: I32,
         a2: I32,
         a3: I32,
         a4: I32,
         a5: I32,
         a6: I32,
         a7: I32,
         a8: I32
       ), lc: I32, ac: I32, i: I32, ofp: I32, val: I32 do
    if(I32.eq(addr, 0),
      do:
        (
          if(I32.ne(res, 0xFF), do: write_variable(res, 0))
          return()
        )
    )

    # Count is passed directly
    ac = count
    ofp = @fp
    @fp = @csp
    push_call_stack(I32.band(@pc, 0xFFFF))
    push_call_stack(I32.shr_u(@pc, 16))
    # Store count instead of mask
    push_call_stack(I32.or(I32.shl(count, 8), res))
    push_call_stack(ofp)

    lc = read_byte(addr)
    @pc = I32.add(addr, 1)

    i = 0

    loop LLoop do
      if I32.lt_u(i, lc) do
        # In V3, we must advance PC for every local to read its default value.
        val = if(I32.le_u(@version, 3), do: fetch_word(), else: 0)

        # If an argument is provided, it overrides the default.
        val =
          if I32.lt_u(i, ac) do
            if(I32.eq(i, 0),
              do: a1,
              else:
                if(I32.eq(i, 1),
                  do: a2,
                  else:
                    if(I32.eq(i, 2),
                      do: a3,
                      else:
                        if(I32.eq(i, 3),
                          do: a4,
                          else:
                            if(I32.eq(i, 4),
                              do: a5,
                              else:
                                if(I32.eq(i, 5), do: a6, else: if(I32.eq(i, 6), do: a7, else: a8))
                            )
                        )
                    )
                )
            )
          else
            val
          end

        push_call_stack(val)
        i = I32.add(i, 1)
        LLoop.continue()
      end
    end
  end

  defw do_return(v: I32), ofp: I32, rpc: T.Address, var: T.Variable do
    if I32.eq(@fp, 0) do
      @halted = 1
      halt(0, @pc, 0)
      return()
    end

    @csp = @fp
    rpc = I32.or(read_call_stack(@fp), I32.shl(read_call_stack(I32.add(@fp, 1)), 16))
    var = I32.band(read_call_stack(I32.add(@fp, 2)), 0xFF)
    ofp = read_call_stack(I32.add(@fp, 3))
    @pc = rpc
    @fp = ofp
    if(I32.ne(var, 0xFF), do: write_variable(var, v))
  end

  defw read_input(buf: T.Address), I32, max: I32, i: I32, char: I32, st: I32 do
    max = read_byte(buf)

    st = if(I32.ge_u(@version, 5), do: I32.const(2), else: I32.const(1))
    i = 0

    Control.block ILoopBlock do
      loop ILoop do
        if I32.lt_u(i, max) do
          char = unicode_to_zscii(ZIO.read_char())

          if I32.ne(char, 13) do
            # V1-4 lowercase conversion
            if I32.lt_u(@version, 5) do
              if I32.ge_u(char, I32.const(65)) do
                if I32.le_u(char, I32.const(90)) do
                  char = I32.add(char, I32.const(32))
                end
              end
            end

            write_byte(I32.add(I32.add(buf, st), i), char)
            i = I32.add(i, 1)
            ILoop.continue()
          else
            ILoopBlock.break()
          end
        end
      end
    end

    if(I32.lt_u(@version, 5),
      do: write_byte(I32.add(I32.add(buf, st), i), 0),
      else: write_byte(I32.add(buf, 1), i)
    )

    13
  end

  defw do_tokenise(t: T.Address, p: T.Address, d: T.Address) do
    if I32.eq(d, 0), do: d = @dictionary_base
    ZIO.tokenize(t, p, d, 0)
  end

  defw do_get_sibling(obj: T.Object), sib: T.Object do
    sib = get_object_sibling(obj)
    fetch_result_and_store(sib)
    fetch_branch(I32.ne(sib, 0))
  end

  defw do_get_child(obj: T.Object), child: T.Object do
    child = get_object_child(obj)
    fetch_result_and_store(child)
    fetch_branch(I32.ne(child, 0))
  end

  defw do_insert_obj(obj: T.Object, dest: T.Object), old_parent: T.Object do
    old_parent = get_object_parent(obj)
    set_object_parent(obj, dest)

    if I32.ne(old_parent, 0) do
      remove_from_siblings(obj, old_parent)
    end

    if I32.ne(dest, 0) do
      add_to_children(obj, dest)
    end
  end

  defw do_remove_obj(obj: T.Object), old_parent: T.Object do
    old_parent = get_object_parent(obj)

    if I32.ne(old_parent, 0) do
      remove_from_siblings(obj, old_parent)
      set_object_parent(obj, 0)
      set_object_sibling(obj, 0)
    end
  end

  defw do_set_font(f: I32), old: I32 do
    if I32.or(I32.eq(f, 1), I32.eq(f, 3)) do
      old = @current_font
      @current_font = f
      fetch_result_and_store(old)
    else
      fetch_result_and_store(0)
    end
  end

  defw do_copy_table(src: T.Address, dest: T.Address, len: I32), i: I32 do
    if I32.eq(dest, 0) do
      # fill src with 0? No, Spec 14 says:
      # If dest is zero, then len bytes of src are filled with zeroes.
      i = 0

      loop FLoop do
        if I32.lt_u(i, len) do
          write_byte(I32.add(src, i), 0)
          i = I32.add(i, 1)
          FLoop.continue()
        end
      end

      return()
    end

    # Actually if len is negative, copy but allow overlap?
    # Spec says: if len is negative, copying is done forward. If positive, backward?
    # No, Spec 14 says:
    # if len is negative, copying is done byte by byte ... to allow overlaps.
    # if positive, copying is done so that no overlap occurs.
    if I32.lt_s(len, 0) do
      len = I32.sub(0, len)
      i = 0

      loop CL1 do
        if I32.lt_u(i, len) do
          write_byte(I32.add(dest, i), read_byte(I32.add(src, i)))
          i = I32.add(i, 1)
          CL1.continue()
        end
      end
    else
      i = 0

      loop CL2 do
        if I32.lt_u(i, len) do
          write_byte(I32.add(dest, i), read_byte(I32.add(src, i)))
          i = I32.add(i, 1)
          CL2.continue()
        end
      end
    end
  end

  defw do_print_table(tab: T.Address, width: I32, height: I32, skip: I32), i: I32, j: I32 do
    if I32.eq(height, 0), do: height = 1
    i = 0

    loop HLoop do
      if I32.lt_u(i, height) do
        j = 0

        loop WLoop do
          if I32.lt_u(j, width) do
            print_char_wasm(zscii_to_unicode(read_byte(I32.add(tab, j))))
            j = I32.add(j, 1)
            WLoop.continue()
          end
        end

        # print_char_wasm(13) # Newline?
        tab = I32.add(tab, I32.add(width, skip))
        i = I32.add(i, 1)
        HLoop.continue()
      end
    end
  end

  # --- Dispatch ---
  defw step(), nil,
    b: I32,
    opc: I32,
    t1: I32,
    t2: I32,
    o1: I32,
    o2: I32,
    o3: I32,
    o4: I32,
    o5: I32,
    o6: I32,
    o7: I32,
    o8: I32,
    m: I32 do
    b = fetch_byte()

    if I32.eq(I32.band(b, 0xC0), 0xC0) do
      opc = I32.band(b, 0x1F)
      t1 = fetch_byte()

      if I32.band(b, 0x20) do
        if I32.or(I32.eq(opc, 0x0C), I32.eq(opc, 0x1A)) do
          t2 = fetch_byte()
          o1 = fetch_var_operand(I32.band(I32.shr_u(t1, 6), 3))
          o2 = fetch_var_operand(I32.band(I32.shr_u(t1, 4), 3))
          o3 = fetch_var_operand(I32.band(I32.shr_u(t1, 2), 3))
          o4 = fetch_var_operand(I32.band(t1, 3))
          o5 = fetch_var_operand(I32.band(I32.shr_u(t2, 6), 3))
          o6 = fetch_var_operand(I32.band(I32.shr_u(t2, 4), 3))
          o7 = fetch_var_operand(I32.band(I32.shr_u(t2, 2), 3))
          o8 = fetch_var_operand(I32.band(t2, 3))

          do_call(
            unpack_routine_address(o1),
            if(I32.eq(opc, 0x0C), do: fetch_byte(), else: 0xFF),
            calculate_arg_count2(t1, t2),
            o2,
            o3,
            o4,
            o5,
            o6,
            o7,
            o8,
            0
          )

          return()
        end
      end

      if I32.eq(I32.band(b, 0x20), 0) do
        # bit 5 is 0 -> 2OP opcode in Variable form (opc 0-31)
        if I32.eq(opc, 0x01) do
          o1 = fetch_var_operand(I32.band(I32.shr_u(t1, 6), 3))
          o2 = fetch_var_operand(I32.band(I32.shr_u(t1, 4), 3))
          o3 = fetch_var_operand(I32.band(I32.shr_u(t1, 2), 3))
          o4 = fetch_var_operand(I32.band(t1, 3))
          execute_je(o1, o2, o3, o4, t1)
          return()
        end

        o1 =
          if(I32.eq(opc, 4) or I32.eq(opc, 5) or I32.eq(opc, 13),
            do:
              if(I32.eq(I32.band(I32.shr_u(t1, 6), 3), 2),
                do: read_variable(fetch_byte()),
                else: fetch_var_ref_operand(I32.band(I32.shr_u(t1, 6), 3))
              ),
            else: fetch_var_operand(I32.band(I32.shr_u(t1, 6), 3))
          )

        o2 = fetch_var_operand(I32.band(I32.shr_u(t1, 4), 3))
        _ = fetch_raw_operand(I32.band(I32.shr_u(t1, 2), 3))
        _ = fetch_raw_operand(I32.band(t1, 3))
        execute_2op(opc, o1, o2)
        return()
      end

      # bit 5 is 1 -> VAR opcode (opc 0-31)
      o1 = fetch_var_operand(I32.band(I32.shr_u(t1, 6), 3))
      o2 = fetch_var_operand(I32.band(I32.shr_u(t1, 4), 3))
      o3 = fetch_var_operand(I32.band(I32.shr_u(t1, 2), 3))
      o4 = fetch_var_operand(I32.band(t1, 3))
      o5 = 0
      o6 = 0
      o7 = 0
      o8 = 0

      t2 = 0xFF

      execute_var(opc, t1, t2, o1, o2, o3, o4, o5, o6, o7, o8)
      return()
    end

    if I32.eq(I32.band(b, 0xC0), 0x80) do
      if I32.eq(b, 0xBE) do
        if I32.ge_u(@version, I32.const(5)) do
          opc = fetch_byte()
          t1 = fetch_byte()
          o1 = fetch_var_operand(I32.band(I32.shr_u(t1, 6), 3))
          o2 = fetch_var_operand(I32.band(I32.shr_u(t1, 4), 3))
          o3 = fetch_var_operand(I32.band(I32.shr_u(t1, 2), 3))
          o4 = fetch_var_operand(I32.band(t1, 3))
          execute_ext(opc, o1, o2, o3, o4)
          return()
        end
      end

      # Short form
      t1 = I32.band(I32.shr_u(b, 4), 3)
      opc = I32.band(b, 0x0F)

      if I32.ne(t1, 3) do
        o1 =
          if(I32.eq(opc, 5) or I32.eq(opc, 6) or I32.eq(opc, 14),
            do:
              if(I32.eq(t1, 2),
                do: read_variable(fetch_byte()),
                else: fetch_var_ref_operand(t1)
              ),
            else: fetch_operand(t1)
          )

        execute_1op(opc, o1)
        return()
      end

      execute_0op(opc)
      return()
    end

    # Long form 2OP
    opc = I32.band(b, 31)
    o1 = if I32.band(b, 0x40), do: read_variable(fetch_byte()), else: fetch_byte()
    o2 = if I32.band(b, 0x20), do: read_variable(fetch_byte()), else: fetch_byte()
    execute_2op(opc, o1, o2)
  end

  defw run_steps(max: I32) do
    Control.block StepLoopBlock do
      loop StepLoop do
        if I32.or(I32.lt_u(max, I32.const(1)), @halted) do
          StepLoopBlock.break()
        end

        step()
        max = I32.sub(max, I32.const(1))
        StepLoop.continue()
      end
    end
  end

  defw load_story(ptr: T.Address, len: I32), i: I32 do
    i = 0
    @story_len = len

    loop CLoop do
      if(I32.lt_u(i, len),
        do:
          (
            Memory.store!(I32.U8, i, Memory.load!(I32.U8, I32.add(ptr, i)))
            i = I32.add(i, 1)
            CLoop.continue()
          )
      )
    end
  end

  defw unpack_routine_address(addr: T.PackedAddress), T.Address do
    I32.add(I32.shl(addr, @packed_address_shift), @routine_offset)
  end

  defw unpack_string_address(addr: T.PackedAddress), T.Address do
    I32.add(I32.shl(addr, @packed_address_shift), @string_offset)
  end

  defw init(st_off: T.Address), addr: T.Address do
    @version = read_byte(0)
    @globals_base = read_word(0x0C)
    @dictionary_base = read_word(0x08)
    @object_table_base = read_word(0x0A)
    @static_memory_base = read_word(0x0E)
    @abbreviations_base = read_word(0x18)
    @sp = 0
    @csp = 0
    @fp = 0
    @current_font = 1
    @current_alphabet = 0
    @next_alphabet = -1
    @capabilities = ZIO.get_capabilities()

    if I32.ge_u(@version, 4) do
      # Spec 11.1.2: Flags 2 at offset 0x10
      # Bit 3: Font 3 available
      # Bit 4: Timed input available
      # Bit 5: Sound effects available
      # Bit 7: Multiple windows available
      write_word(0x10, I32.or(read_word(0x10), @capabilities))
    end

    if I32.eq(@version, 1) do
      # V1 A2 alphabet (Spec 3.5.2)
      # Space at index 0 (Z-char 6)
      Memory.store!(I32.U8, 0x81034, 32)
      # 0
      Memory.store!(I32.U8, 0x81035, 48)
      # 1
      Memory.store!(I32.U8, 0x81036, 49)
      # 2
      Memory.store!(I32.U8, 0x81037, 50)
      # 3
      Memory.store!(I32.U8, 0x81038, 51)
      # 4
      Memory.store!(I32.U8, 0x81039, 52)
      # 5
      Memory.store!(I32.U8, 0x8103A, 53)
      # 6
      Memory.store!(I32.U8, 0x8103B, 54)
      # 7
      Memory.store!(I32.U8, 0x8103C, 55)
      # 8
      Memory.store!(I32.U8, 0x8103D, 56)
      # 9
      Memory.store!(I32.U8, 0x8103E, 57)
      # .
      Memory.store!(I32.U8, 0x8103F, 46)
      # ,
      Memory.store!(I32.U8, 0x81040, 44)
      # !
      Memory.store!(I32.U8, 0x81041, 33)
      # ?
      Memory.store!(I32.U8, 0x81042, 63)
      # _
      Memory.store!(I32.U8, 0x81043, 95)
      # #
      Memory.store!(I32.U8, 0x81044, 35)
      # '
      Memory.store!(I32.U8, 0x81045, 39)
      # "
      Memory.store!(I32.U8, 0x81046, 34)
      # /
      Memory.store!(I32.U8, 0x81047, 47)
      # \
      Memory.store!(I32.U8, 0x81048, 92)
      # <
      Memory.store!(I32.U8, 0x81049, 60)
      # -
      Memory.store!(I32.U8, 0x8104A, 45)
      # :
      Memory.store!(I32.U8, 0x8104B, 58)
      # (
      Memory.store!(I32.U8, 0x8104C, 40)
      # )
      Memory.store!(I32.U8, 0x8104D, 41)
    else
      if I32.eq(@version, 2) do
        # V2 A2 alphabet: " \r0123456789.,!?_#'"/\\-:( )"
        # space at index 0 (Z-char 6)
        Memory.store!(I32.U8, 0x81034, 32)
        # \r at index 1 (Z-char 7)
        Memory.store!(I32.U8, 0x81035, 13)
        # 0
        Memory.store!(I32.U8, 0x81036, 48)
        # 1
        Memory.store!(I32.U8, 0x81037, 49)
        # 2
        Memory.store!(I32.U8, 0x81038, 50)
        # 3
        Memory.store!(I32.U8, 0x81039, 51)
        # 4
        Memory.store!(I32.U8, 0x8103A, 52)
        # 5
        Memory.store!(I32.U8, 0x8103B, 53)
        # 6
        Memory.store!(I32.U8, 0x8103C, 54)
        # 7
        Memory.store!(I32.U8, 0x8103D, 55)
        # 8
        Memory.store!(I32.U8, 0x8103E, 56)
        # 9
        Memory.store!(I32.U8, 0x8103F, 57)
        # .
        Memory.store!(I32.U8, 0x81040, 46)
        # ,
        Memory.store!(I32.U8, 0x81041, 44)
        # !
        Memory.store!(I32.U8, 0x81042, 33)
        # ?
        Memory.store!(I32.U8, 0x81043, 63)
        # _
        Memory.store!(I32.U8, 0x81044, 95)
        # #
        Memory.store!(I32.U8, 0x81045, 35)
        # '
        Memory.store!(I32.U8, 0x81046, 39)
        # "
        Memory.store!(I32.U8, 0x81047, 34)
        # /
        Memory.store!(I32.U8, 0x81048, 47)
        # \
        Memory.store!(I32.U8, 0x81049, 92)
        # -
        Memory.store!(I32.U8, 0x8104A, 45)
        # :
        Memory.store!(I32.U8, 0x8104B, 58)
        # (
        Memory.store!(I32.U8, 0x8104C, 40)
        # )
        Memory.store!(I32.U8, 0x8104D, 41)
      else
        # V3+ A2 alphabet: Same as V2 but Z-char 7 (Index 1) is '0'
        # space at index 0 (Z-char 6)
        Memory.store!(I32.U8, 0x81034, 32)
        # 0 at index 1 (Z-char 7) - The V3 change!
        Memory.store!(I32.U8, 0x81035, 48)
        # 0 (Z-char 8) - Keeps V2 alignment
        Memory.store!(I32.U8, 0x81036, 48)
        # 1
        Memory.store!(I32.U8, 0x81037, 49)
        # 2
        Memory.store!(I32.U8, 0x81038, 50)
        # 3
        Memory.store!(I32.U8, 0x81039, 51)
        # 4
        Memory.store!(I32.U8, 0x8103A, 52)
        # 5
        Memory.store!(I32.U8, 0x8103B, 53)
        # 6
        Memory.store!(I32.U8, 0x8103C, 54)
        # 7
        Memory.store!(I32.U8, 0x8103D, 55)
        # 8
        Memory.store!(I32.U8, 0x8103E, 56)
        # 9
        Memory.store!(I32.U8, 0x8103F, 57)
        # .
        Memory.store!(I32.U8, 0x81040, 46)
        # ,
        Memory.store!(I32.U8, 0x81041, 44)
        # !
        Memory.store!(I32.U8, 0x81042, 33)
        # ?
        Memory.store!(I32.U8, 0x81043, 63)
        # _
        Memory.store!(I32.U8, 0x81044, 95)
        # #
        Memory.store!(I32.U8, 0x81045, 35)
        # '
        Memory.store!(I32.U8, 0x81046, 39)
        # "
        Memory.store!(I32.U8, 0x81047, 34)
        # /
        Memory.store!(I32.U8, 0x81048, 47)
        # \
        Memory.store!(I32.U8, 0x81049, 92)
        # -
        Memory.store!(I32.U8, 0x8104A, 45)
        # :
        Memory.store!(I32.U8, 0x8104B, 58)
        # (
        Memory.store!(I32.U8, 0x8104C, 40)
        # )
        Memory.store!(I32.U8, 0x8104D, 41)
      end
    end

    if I32.ge_u(@version, 5) do
      addr = read_word(I32.const(54))

      if I32.ne(addr, I32.const(0)) do
        if I32.ge_u(read_word(addr), I32.const(2)) do
          @unicode_table_base = read_word(I32.add(addr, I32.const(4)))

          if I32.eq(@unicode_table_base, 0) do
            if I32.ge_u(read_word(addr), I32.const(3)) do
              @unicode_table_base = read_word(I32.add(addr, I32.const(6)))
            end
          end
        end
      end
    end

    if I32.eq(@version, 7) do
      @routine_offset = I32.shl(read_word(0x28), 3)
      @string_offset = I32.shl(read_word(0x2A), 3)
    end

    if I32.le_u(@version, 3),
      do:
        (
          @packed_address_shift = 1
          @object_entry_size = 9
          @object_parent_offset = 4
          @object_sibling_offset = 5
          @object_child_offset = 6
          @object_property_table_offset = 7
          @object_table_start = I32.add(@object_table_base, 62)
        ),
      else:
        (
          @packed_address_shift = 2
          @object_entry_size = 14
          @object_parent_offset = 6
          @object_sibling_offset = 8
          @object_child_offset = 10
          @object_property_table_offset = 12
          @object_table_start = I32.add(@object_table_base, 126)
        )

    if(I32.eq(@version, 8), do: @packed_address_shift = 3)

    if I32.eq(@pc, 0) do
      @pc = read_word(6)
    end

    push_call_stack(0)
    push_call_stack(0)
    push_call_stack(0xFF)
    push_call_stack(0)
    @fp = 0
  end

  defw set_pc(npc: I32) do
    @pc = npc
  end

  defw get_pc(), I32 do
    @pc
  end

  defw get_sp(), I32 do
    @sp
  end

  defw set_sp(nsp: I32) do
    @sp = nsp
  end

  defw get_fp(), I32 do
    @fp
  end

  defw get_csp(), I32 do
    @csp
  end

  Memory.initial_data!(
    0x81000,
    "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ \r0123456789.,!?_#'\"/\\-:()"
  )

  Memory.initial_data!(
    0x80000,
    Enum.map_join(@unicode_table, fn u -> <<u::16-big>> end)
  )
end
