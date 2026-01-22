defmodule Zorb.Interpreter.ZIO do
  use Orb.Import, name: :zio
  defw print_char(char: Orb.I32)
end

defmodule Zorb.Interpreter do
  use Orb

  defp header_version, do: 0x00
  defp header_initial_pc, do: 0x06
  defp header_globals_base, do: 0x0C
  defp header_object_table_base, do: 0x0A

  Memory.pages(8) # 512KB

  global do
    @pc 0
    @version 0
    @sp 0
    @fp 0
    @stack_base 0
    @globals_base 0
    @object_table_base 0
    @alphabet_shift 0 # 0=A0, 1=A1, 2=A2
  end

  Orb.Import.register(Zorb.Interpreter.ZIO)

  defw init(stack_offset: I32) do
    @version = Memory.load!(I32.U8, header_version())
    @pc = read_word(header_initial_pc())
    @globals_base = read_word(header_globals_base())
    @object_table_base = read_word(header_object_table_base())
    @stack_base = stack_offset
    @sp = 0
    @fp = 0
    push_stack(0)
    push_stack(0)
    push_stack(0xFF)
    push_stack(0)
    @fp = 0
  end

  defw unpack_address(address: I32), I32 do
    if @version <= 3 do
      return(I32.shl(address, 1))
    end
    if @version <= 5 do
      return(I32.shl(address, 2))
    end
    I32.shl(address, 3)
  end

  defw write_word(address: I32, value: I32) do
    Memory.store!(I32.U8, address, I32.shr_u(value, 8))
    Memory.store!(I32.U8, address + 1, I32.band(value, 0xFF))
  end

  defw read_variable(var: I32), I32 do
    if var === 0 do
      return(pop_stack())
    end
    if var < 16 do
      return(read_stack(@fp + 4 + (var - 1)))
    end
    read_word(@globals_base + I32.shl(var - 16, 1))
  end

  defw write_variable(var: I32, value: I32) do
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

  defw push_stack(value: I32) do
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

  defw read_byte(address: I32), I32 do
    Memory.load!(I32.U8, address)
  end

  defw read_word(address: I32), I32 do
    I32.or(I32.shl(Memory.load!(I32.U8, address), 8), Memory.load!(I32.U8, address + 1))
  end

  defw get_pc(), I32 do
    @pc
  end

  defw set_pc(new_pc: I32) do
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

  defp type_large, do: I32.const(0)
  defp type_small, do: I32.const(1)
  defp type_var,   do: I32.const(2)

  defw fetch_operand(type: I32), I32 do
    if type === type_large(), do: return(fetch_word())
    if type === type_small(), do: return(fetch_byte())
    if type === type_var(), do: return(read_variable(fetch_byte()))
    0
  end

  defw get_object_address(object: I32), I32 do
    if @version <= 3 do
      return(@object_table_base + 62 + (object - 1) * 9)
    end
    @object_table_base + 126 + (object - 1) * 14
  end

  defw get_object_parent(object: I32), I32, addr: I32 do
    addr = get_object_address(object)
    if @version <= 3, do: return(read_byte(addr + 4))
    read_word(addr + 6)
  end

  defw get_object_sibling(object: I32), I32, addr: I32 do
    addr = get_object_address(object)
    if @version <= 3, do: return(read_byte(addr + 5))
    read_word(addr + 8)
  end

  defw get_object_child(object: I32), I32, addr: I32 do
    addr = get_object_address(object)
    if @version <= 3, do: return(read_byte(addr + 6))
    read_word(addr + 10)
  end

  defw get_prop_table_address(object: I32), I32, addr: I32 do
    addr = get_object_address(object)
    if @version <= 3, do: return(read_word(addr + 7))
    read_word(addr + 12)
  end

  defw get_prop_address(object: I32, property: I32), I32, addr: I32, byte: I32, size: I32, prop_num: I32 do
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
        return(0)
      end
      
      PropLoop.continue(if: prop_num > property)
    end
    0
  end

  defw step(), byte: I32, types_byte: I32 do
    byte = fetch_byte()
    
    if byte < 0x80 do # 2OP
      execute_2op(I32.band(byte, 0x1F), fetch_operand(if I32.band(byte, 0x40) > 0, result: I32, do: type_var(), else: type_small()), fetch_operand(if I32.band(byte, 0x20) > 0, result: I32, do: type_var(), else: type_small()))
      return()
    end

    if byte < 0xB0 do # 1OP
      execute_1op(I32.band(byte, 0x0F), fetch_operand(I32.band(I32.shr_u(byte, 4), 0x03)))
      return()
    end

    if byte < 0xC0 do # 0OP
      execute_0op(I32.band(byte, 0x0F))
      return()
    end

    types_byte = fetch_byte()
    execute_var(I32.band(byte, 0x1F), 
      fetch_operand(I32.band(I32.shr_u(types_byte, 6), 0x03)),
      fetch_operand(I32.band(I32.shr_u(types_byte, 4), 0x03)),
      fetch_operand(I32.band(I32.shr_u(types_byte, 2), 0x03)),
      fetch_operand(I32.band(types_byte, 0x03))
    )
  end

  defw execute_2op(opcode: I32, op1: I32, op2: I32), addr: I32, byte: I32, prop_num: I32, size: I32 do
    if opcode === 1, do: return(fetch_branch(op1 === op2))
    if opcode === 2, do: return(fetch_branch(I32.lt_s(op1, op2)))
    if opcode === 3, do: return(fetch_branch(I32.gt_s(op1, op2)))
    if opcode === 4 do
      addr = get_object_address(op1)
      byte = read_byte(addr + I32.shr_u(op2, 3))
      Memory.store!(I32.U8, addr + I32.shr_u(op2, 3), I32.or(byte, I32.shl(1, 7 - I32.band(op2, 7))))
      return()
    end
    if opcode === 5 do
      addr = get_object_address(op1)
      byte = read_byte(addr + I32.shr_u(op2, 3))
      Memory.store!(I32.U8, addr + I32.shr_u(op2, 3), I32.band(byte, I32.xor(I32.shl(1, 7 - I32.band(op2, 7)), 0xFF)))
      return()
    end
    if opcode === 6 do
      addr = get_object_address(op1)
      byte = read_byte(addr + I32.shr_u(op2, 3))
      fetch_branch(I32.band(byte, I32.shl(1, 7 - I32.band(op2, 7))) !== 0)
      return()
    end
    if opcode === 8, do: return(fetch_result_and_store(I32.or(op1, op2)))
    if opcode === 9, do: return(fetch_result_and_store(I32.band(op1, op2)))
    if opcode === 14 do
      addr = get_prop_address(op1, op2)
      if addr === 0 do
        fetch_result_and_store(read_word(@object_table_base + I32.shl(op2 - 1, 1)))
      else
        if I32.shr_u(read_byte(addr - 1), 5) === 0 do
          fetch_result_and_store(read_byte(addr))
        else
          fetch_result_and_store(read_word(addr))
        end
      end
      return()
    end
    if opcode === 15, do: return(fetch_result_and_store(read_word(op1 + I32.shl(op2, 1))))
    if opcode === 16, do: return(fetch_result_and_store(read_byte(op1 + op2)))
    if opcode === 17 do
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

  defw execute_1op(opcode: I32, op1: I32), sibling: I32, child: I32 do
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
      fetch_result_and_store(I32.shr_u(read_byte(op1 - 1), 5) + 1)
      return()
    end
    if opcode === 5, do: return(write_variable(op1, read_variable(op1) + 1))
    if opcode === 6, do: return(write_variable(op1, read_variable(op1) - 1))
    if opcode === 15, do: return(fetch_result_and_store(I32.xor(op1, 0xFFFF)))
  end

  defw print_zstring(), word: I32, done: I32, z1: I32, z2: I32, z3: I32 do
    @alphabet_shift = 0
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
  end

  defw decode_zchar(zchar: I32) do
    if zchar === 0 do
      Zorb.Interpreter.ZIO.print_char(32)
      @alphabet_shift = 0
      return()
    end
    if zchar === 4 do
      @alphabet_shift = 1
      return()
    end
    if zchar === 5 do
      @alphabet_shift = 2
      return()
    end
    
    if @alphabet_shift === 0 do
      Zorb.Interpreter.ZIO.print_char(zchar + 91)
      @alphabet_shift = 0
      return()
    end
    if @alphabet_shift === 1 do
      Zorb.Interpreter.ZIO.print_char(zchar + 59)
      @alphabet_shift = 0
      return()
    end
    @alphabet_shift = 0
  end

  defw execute_0op(opcode: I32) do
    if opcode === 0, do: return(do_return(1))
    if opcode === 1, do: return(do_return(0))
    if opcode === 2, do: return(print_zstring())
    if opcode === 8, do: return(do_return(pop_stack()))
  end

  defw execute_var(opcode: I32, op1: I32, op2: I32, op3: I32, op4: I32), addr: I32 do
    if opcode === 0 do
      if op1 === 0 do
        fetch_result_and_store(0)
      else
        do_call(unpack_address(op1), fetch_byte())
      end
      return()
    end
    if opcode === 1, do: return(write_word(op1 + I32.shl(op2, 1), op3))
    if opcode === 2, do: return(Memory.store!(I32.U8, op1 + op2, op3))
    if opcode === 3 do
      addr = get_prop_address(op1, op2)
      if addr !== 0 do
        if I32.shr_u(read_byte(addr - 1), 5) === 0 do
          Memory.store!(I32.U8, addr, op3)
        else
          write_word(addr, op3)
        end
      end
      return()
    end
    if opcode === 5, do: return(Zorb.Interpreter.ZIO.print_char(op1))
    if opcode === 7, do: return(fetch_result_and_store(1))
  end

  defw do_call(address: I32, result_var: I32), locals_count: I32, i: I32, old_fp: I32 do
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

  defw do_return(value: I32), old_fp: I32, return_pc: I32, store_var: I32 do
    return_pc = I32.or(read_stack(@fp), I32.shl(read_stack(@fp + 1), 16))
    store_var = read_stack(@fp + 2)
    old_fp = read_stack(@fp + 3)
    if return_pc === 0, do: return()
    @pc = return_pc
    @sp = @fp
    @fp = old_fp
    if store_var !== 0xFF, do: write_variable(store_var, value)
  end

  defw fetch_result_and_store(value: I32), result_var: I32 do
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
