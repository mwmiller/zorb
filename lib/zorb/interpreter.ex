defmodule Zorb.Interpreter do
  use Orb

  defp header_version, do: 0x00
  defp header_initial_pc, do: 0x06
  defp header_globals_base, do: 0x0C

  Memory.pages(8) # 512KB

  global do
    @pc 0
    @version 0
    @sp 0
    @fp 0
    @stack_base 0
    @globals_base 0
  end

  defmodule ZIO do
    use Orb.Import, name: :zio
    defw print_char(char: I32)
  end

  Orb.Import.register(ZIO)

  defw init(stack_offset: I32) do
    @version = Memory.load!(I32.U8, header_version())
    @pc = read_word(header_initial_pc())
    @globals_base = read_word(header_globals_base())
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
  defp type_omit,  do: I32.const(3)

  defw fetch_operand(type: I32), I32 do
    if type === type_large() do
      return(fetch_word())
    end
    if type === type_small() do
      return(fetch_byte())
    end
    if type === type_var() do
      return(read_variable(fetch_byte()))
    end
    0
  end

  defw step(), byte: I32, op1: I32, op2: I32, op3: I32, op4: I32, type1: I32, type2: I32, type3: I32, type4: I32, opcode: I32, types_byte: I32 do
    byte = fetch_byte()
    
    if byte < 0x80 do # 2OP
      type1 = if I32.band(byte, 0x40) > 0, result: I32, do: type_var(), else: type_small()
      type2 = if I32.band(byte, 0x20) > 0, result: I32, do: type_var(), else: type_small()
      opcode = I32.band(byte, 0x1F)
      execute_2op(opcode, fetch_operand(type1), fetch_operand(type2))
      return()
    end

    if byte < 0xB0 do # 1OP
      opcode = I32.band(byte, 0x0F)
      execute_1op(opcode, fetch_operand(I32.band(I32.shr_u(byte, 4), 0x03)))
      return()
    end

    if byte < 0xC0 do # 0OP
      execute_0op(I32.band(byte, 0x0F))
      return()
    end

    # VAR
    opcode = I32.band(byte, 0x1F)
    types_byte = fetch_byte()
    type1 = I32.band(I32.shr_u(types_byte, 6), 0x03)
    type2 = I32.band(I32.shr_u(types_byte, 4), 0x03)
    type3 = I32.band(I32.shr_u(types_byte, 2), 0x03)
    type4 = I32.band(types_byte, 0x03)
    
    execute_var(opcode, fetch_operand(type1), fetch_operand(type2), fetch_operand(type3), fetch_operand(type4))
  end

  defw execute_2op(opcode: I32, op1: I32, op2: I32) do
    if opcode === 1, do: return(fetch_branch(op1 === op2))
    if opcode === 2, do: return(fetch_branch(I32.lt_s(op1, op2)))
    if opcode === 3, do: return(fetch_branch(I32.gt_s(op1, op2)))
    if opcode === 8, do: return(fetch_result_and_store(I32.or(op1, op2)))
    if opcode === 9, do: return(fetch_result_and_store(I32.band(op1, op2)))
    if opcode === 15, do: return(fetch_result_and_store(read_word(op1 + I32.shl(op2, 1))))
    if opcode === 16, do: return(fetch_result_and_store(read_byte(op1 + op2)))
    if opcode === 20, do: return(fetch_result_and_store(op1 + op2))
    if opcode === 21, do: return(fetch_result_and_store(op1 - op2))
    if opcode === 22, do: return(fetch_result_and_store(op1 * op2))
    if opcode === 23, do: return(fetch_result_and_store(I32.div_s(op1, op2)))
    if opcode === 24, do: return(fetch_result_and_store(I32.rem_s(op1, op2)))
  end

  defw execute_1op(opcode: I32, op1: I32) do
    if opcode === 0, do: return(fetch_branch(op1 === 0))
    if opcode === 5, do: return(write_variable(op1, read_variable(op1) + 1))
    if opcode === 6, do: return(write_variable(op1, read_variable(op1) - 1))
    if opcode === 15, do: return(fetch_result_and_store(I32.xor(op1, 0xFFFF)))
  end

  defw execute_0op(opcode: I32) do
    if opcode === 0, do: return(do_return(1))
    if opcode === 1, do: return(do_return(0))
    if opcode === 8, do: return(do_return(pop_stack()))
  end

  defw execute_var(opcode: I32, op1: I32, op2: I32, op3: I32, op4: I32) do
    if opcode === 0 do
      if op1 === 0, do: return(fetch_result_and_store(0))
      return(do_call(unpack_address(op1), fetch_byte()))
    end
    if opcode === 1, do: return(write_word(op1 + I32.shl(op2, 1), op3))
    if opcode === 2, do: return(Memory.store!(I32.U8, op1 + op2, op3))
    if opcode === 5, do: return(ZIO.print_char(op1))
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
