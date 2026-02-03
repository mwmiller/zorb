defw read_byte(addr: T.Address), I32 do
  Memory.load!(I32.U8, addr)
end

defw read_word(addr: T.Address), I32 do
  I32.or(I32.shl(Memory.load!(I32.U8, addr), 8), Memory.load!(I32.U8, I32.add(addr, 1)))
end

defw write_byte(addr: T.Address, val: I32) do
  if(I32.ge_u(addr, @static_memory_base),
    do: z_halt(4, @pc, 0),
    else: Memory.store!(I32.U8, addr, I32.band(val, 0xFF))
  )
end

defw write_word(addr: T.Address, val: I32) do
  if I32.ge_u(addr, @static_memory_base), do: Orb.Control.return(z_halt(4, @pc, 0))
  Memory.store!(I32.U8, addr, I32.shr_u(val, 8))
  Memory.store!(I32.U8, I32.add(addr, 1), I32.band(val, 0xFF))
end

defw z_halt(reason: I32, pc: I32, opcode: I32) do
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
  if(I32.ge_u(@sp, 1024), do: z_halt(1, @pc, 0))
  write_stack(@sp, val)
  @sp = I32.add(@sp, 1)
end

defw pop_stack(), I32 do
  if(I32.eq(@sp, 0), do: z_halt(2, @pc, 0))
  @sp = I32.sub(@sp, 1)
  read_stack(@sp)
end

defw peek_stack(), I32 do
  if(I32.eq(@sp, 0), do: z_halt(2, @pc, 0))
  read_stack(I32.sub(@sp, 1))
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

defw read_stack(idx: I32), I32 do
  read_word(I32.add(@stack_base, I32.shl(idx, 1)))
end

defw write_stack(idx: I32, val: I32) do
  write_word_direct(I32.add(@stack_base, I32.shl(idx, 1)), val)
end

defw write_word_direct(addr: T.Address, val: I32) do
  Memory.store!(I32.U8, addr, I32.shr_u(val, 8))
  Memory.store!(I32.U8, I32.add(addr, 1), I32.band(val, 0xFF))
end

defwp fetch_byte(), I32 do
  val = read_byte(@pc)
  @pc = I32.add(@pc, 1)
  val
end

defwp fetch_word(), I32 do
  val = read_word(@pc)
  @pc = I32.add(@pc, 2)
  val
end

defw execute_2op(opc: I32, types: I32) do
  v1 = fetch_operand(I32.band(I32.shr_u(types, 6), 0x03))
  v2 = fetch_operand(I32.band(I32.shr_u(types, 4), 0x03))

  case opc do
    # 1: je
    1 ->
      if I32.eq(v1, v2) do
        fetch_branch(1)
      else
        fetch_branch(0)
      end

    # 2: jl
    2 ->
      if I32.lt_s(v1, v2) do
        fetch_branch(1)
      else
        fetch_branch(0)
      end

    # 3: jg
    3 ->
      if I32.gt_s(v1, v2) do
        fetch_branch(1)
      else
        fetch_branch(0)
      end

    # 4: jin
    4 ->
      if I32.eq(get_object_parent(v1), v2) do
        fetch_branch(1)
      else
        fetch_branch(0)
      end

    # 5: jin_obj (test_attr)
    5 ->
      if check_attribute(v1, v2) do
        fetch_branch(1)
      else
        fetch_branch(0)
      end

    # 6: set_attr
    6 ->
      set_attribute(v1, v2)

    # 7: clear_attr
    7 ->
      clear_attribute(v1, v2)

    # 8: store
    8 ->
      write_variable_replace(v1, v2)

    # 9: insert_obj
    9 ->
      do_insert_obj(v1, v2)

    # 10: loadw
    10 ->
      fetch_result_and_store(read_word(I32.add(v1, I32.shl(v2, 1))))

    # 11: loadb
    11 ->
      fetch_result_and_store(read_byte(I32.add(v1, v2)))

    # 12: get_prop
    12 ->
      fetch_result_and_store(get_prop_value(v1, v2))

    # 13: get_prop_addr
    13 ->
      fetch_result_and_store(get_prop_address(v1, v2))

    # 14: get_next_prop
    14 ->
      fetch_result_and_store(get_next_prop(v1, v2))

    # 15: add
    15 ->
      fetch_result_and_store(I32.add(v1, v2))

    # 16: sub
    16 ->
      fetch_result_and_store(I32.sub(v1, v2))

    # 17: mul
    17 ->
      fetch_result_and_store(I32.mul(v1, v2))

    # 18: div
    18 ->
      if I32.eq(v2, 0) do
        z_halt(3, @pc, opc)
      else
        fetch_result_and_store(I32.div_s(v1, v2))
      end

    # 19: mod
    19 ->
      if I32.eq(v2, 0) do
        z_halt(3, @pc, opc)
      else
        fetch_result_and_store(I32.rem_s(v1, v2))
      end

    # 20: call_2s (V4)
    20 ->
      v_at_least(4) do
        do_call(v1, v2, 0, 0, 1)
      else
        z_halt(3, @pc, opc)
      end

    # 21: call_2n (V5)
    21 ->
      v_at_least(5) do
        do_call(v1, v2, 0, 0, 0)
      else
        z_halt(3, @pc, opc)
      end

    # 22: set_colour (V5/V6)
    22 ->
      # No-op for now
      nil

    # 23: throw (V5/V6)
    23 ->
      # No-op for now
      nil

    _ ->
      z_halt(3, @pc, opc)
  end
end

defw execute_1op(opc: I32, type: I32) do
  val = fetch_operand(type)

  case opc do
    # 0: jz
    0 ->
      if I32.eq(val, 0) do
        fetch_branch(1)
      else
        fetch_branch(0)
      end

    # 1: get_sibling
    1 ->
      do_get_sibling(val)

    # 2: get_child
    2 ->
      do_get_child(val)

    # 3: get_parent
    3 ->
      fetch_result_and_store(get_object_parent(val))

    # 4: get_prop_len
    4 ->
      if I32.eq(val, 0) do
        fetch_result_and_store(0)
      else
        fetch_result_and_store(get_prop_data_size(I32.sub(val, 1)))
      end

    # 5: inc
    5 ->
      write_variable_replace(val, I32.add(read_variable_peek(val), 1))

    # 6: dec
    6 ->
      write_variable_replace(val, I32.sub(read_variable_peek(val), 1))

    # 7: print_addr
    7 ->
      print_zstring(val)

    # 8: call_1s (V4)
    8 ->
      v_at_least(4) do
        do_call(val, 0, 0, 0, 1)
      else
        z_halt(3, @pc, opc)
      end

    # 9: remove_obj
    9 ->
      do_remove_obj(val)

    # 10: print_obj
    10 ->
      # print name of object
      print_zstring(I32.add(get_prop_table_address(val), 1))

    # 11: ret
    11 ->
      do_return(val)

    # 12: jump
    12 ->
      @pc = I32.add(@pc, I32.sub(extend_14(I32.band(val, 0xFFFF)), 2))

    # 13: print_paddr
    13 ->
      print_zstring(unpack_string_address(val))

    # 14: load
    14 ->
      fetch_result_and_store(read_variable_peek(val))

    # 15: not (V1-V4), call_1n (V5+)
    15 ->
      v_at_least(5) do
        do_call(val, 0, 0, 0, 0)
      else
        fetch_result_and_store(I32.xor(val, 0xFFFF))
      end

    _ ->
      z_halt(3, @pc, opc)
  end
end

defw execute_0op(opc: I32) do
  case opc do
    # 0: rtrue
    0 ->
      do_return(1)

    # 1: rfalse
    1 ->
      do_return(0)

    # 2: print
    2 ->
      print_zstring(@pc)
      # Advance PC over the string
      @pc = I32.add(@pc, get_zstring_byte_length(@pc))

    # 3: print_ret
    3 ->
      print_zstring(@pc)
      print_char_wasm(10)
      do_return(1)

    # 4: nop
    4 ->
      nil

    # 5: save (V1-V3)
    5 ->
      # Placeholder
      fetch_branch(0)

    # 6: restore (V1-V3)
    6 ->
      # Placeholder
      fetch_branch(0)

    # 7: restart
    7 ->
      z_halt(0, @pc, 0)

    # 8: ret_popped
    8 ->
      do_return(pop_stack())

    # 9: pop (V1-V4), catch (V5+)
    9 ->
      v_at_least(5) do
        # catch
        fetch_result_and_store(@csp)
      else
        drop_i32(pop_stack())
      end

    # 10: quit
    10 ->
      z_halt(0, @pc, 0)

    # 11: new_line
    11 ->
      print_char_wasm(10)

    # 12: show_status (V3)
    12 ->
      nil

    # 13: verify (V3+)
    13 ->
      do_verify()

    # 14: extended (V5+)
    14 ->
      op = fetch_byte()
      execute_ext(op)

    # 15: piracy (V5+)
    15 ->
      fetch_branch(1)

    _ ->
      z_halt(3, @pc, opc)
  end
end

defw execute_var(opc: I32, types: I32) do
  # VAR can have up to 4 operands, or 8 for call_vs2/call_vn2
  # For now, handle 4
  v1 = fetch_operand(I32.band(I32.shr_u(types, 6), 0x03))
  v2 = fetch_operand(I32.band(I32.shr_u(types, 4), 0x03))
  v3 = fetch_operand(I32.band(I32.shr_u(types, 2), 0x03))
  v4 = fetch_operand(I32.band(types, 0x03))

  case opc do
    # 0: call
    0 ->
      do_call(v1, v2, v3, v4, 1)

    # 1: storew
    1 ->
      write_word(I32.add(v1, I32.shl(v2, 1)), v3)

    # 2: storeb
    2 ->
      write_byte(I32.add(v1, v2), v3)

    # 3: put_prop
    3 ->
      put_prop_value(v1, v2, v3)

    # 4: sread
    4 ->
      read_input(v1, v2)

    # 5: print_char
    5 ->
      print_char_wasm(v1)

    # 6: print_num
    6 ->
      print_number(v1)

    # 7: random
    7 ->
      do_random(v1)

    # 8: push
    8 ->
      push_stack(v1)

    # 9: pull
    9 ->
      write_variable_replace(v1, pop_stack())

    # 10: split_window (V3+)
    10 ->
      nil

    # 11: set_window (V3+)
    11 ->
      nil

    # 12: call_vs2 (V4+)
    12 ->
      # Requires 8 operands
      z_halt(3, @pc, opc)

    # 13: erase_window (V4+)
    13 ->
      nil

    # 14: erase_line (V4+)
    14 ->
      nil

    # 15: set_cursor (V4+)
    15 ->
      nil

    # 16: get_cursor (V4+)
    16 ->
      nil

    # 17: set_text_style (V4+)
    17 ->
      nil

    # 18: buffer_mode (V4+)
    18 ->
      nil

    # 19: output_stream (V3+)
    19 ->
      do_output_stream(v1, v2)

    # 20: input_stream (V3+)
    20 ->
      nil

    # 21: sound_effect (V3+)
    21 ->
      nil

    # 22: read_char (V4+)
    22 ->
      fetch_result_and_store(ZIO.read_char())

    # 23: scan_table (V4+)
    23 ->
      do_scan_table(v1, v2, v3, v4)

    # 24: not (V5+)
    24 ->
      fetch_result_and_store(I32.xor(v1, 0xFFFF))

    # 25: call_vn (V5+)
    25 ->
      do_call(v1, v2, v3, v4, 0)

    # 26: call_vn2 (V5+)
    26 ->
      # Requires 8 operands
      z_halt(3, @pc, opc)

    # 27: tokenise (V5+)
    27 ->
      do_tokenise(v1, v2, v3, v4)

    # 28: encode_text (V5+)
    28 ->
      nil

    # 29: copy_table (V5+)
    29 ->
      do_copy_table(v1, v2, v3)

    # 30: print_table (V5+)
    30 ->
      do_print_table(v1, v2, v3, v4)

    # 31: check_arg_count (V5+)
    31 ->
      expected = v1
      actual = read_call_stack(I32.add(@fp, 3))

      if I32.ge_u(actual, expected) do
        fetch_branch(1)
      else
        fetch_branch(0)
      end

    _ ->
      z_halt(3, @pc, opc)
  end
end

defw execute_ext(opc: I32) do
  # Placeholder for EXT opcodes (V5+)
  # Many of these are VAR-like
  z_halt(3, @pc, I32.or(0x1000, opc))
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
        I32.const(0)
      end
    end
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
        I32.const(0)
      end
    end
  end
end

defwp fetch_branch(cond: I32) do
  # Spec 4.7
  byte = fetch_byte()
  target = 0

  if I32.eq(I32.band(byte, 0x80), 0) do
    # 14-bit offset
    target = extend_14(I32.or(I32.shl(I32.band(byte, 0x3F), 8), fetch_byte()))
  else
    # 6-bit offset
    target = I32.band(byte, 0x3F)
  end

  if I32.ne(I32.band(byte, 0x40), 0) do
    # Jump if true
    if I32.ne(cond, 0) do
      if I32.eq(target, 0) do
        do_return(0)
      else
        if I32.eq(target, 1) do
          do_return(1)
        else
          @pc = I32.add(@pc, I32.sub(target, 2))
        end
      end
    end
  else
    # Jump if false
    if I32.eq(cond, 0) do
      if I32.eq(target, 0) do
        do_return(0)
      else
        if I32.eq(target, 1) do
          do_return(1)
        else
          @pc = I32.add(@pc, I32.sub(target, 2))
        end
      end
    end
  end
end

defwp extend_14(val: I32), I32 do
  if I32.ne(I32.band(val, 0x2000), 0) do
    I32.or(val, 0xFFFFC000)
  else
    val
  end
end

defwp fetch_result_and_store(val: I32) do
  write_variable(fetch_byte(), val)
end

defwp fetch_result_and_store_replace(val: I32) do
  write_variable_replace(fetch_byte(), val)
end

defw do_call(routine: I32, v1: I32, v2: I32, v3: I32, store: I32) do
  if I32.eq(routine, 0) do
    if I32.ne(store, 0) do
      fetch_result_and_store(0)
    end
  else
    addr = unpack_routine_address(routine)

    # Routine header: number of locals
    num_locals = read_byte(addr)
    addr = I32.add(addr, 1)

    # Save current state on call stack
    # Return address
    push_call_stack(@pc)
    # Frame pointer
    push_call_stack(@fp)
    # Result store flag (highest bit) | variable index
    if I32.ne(store, 0) do
      push_call_stack(I32.or(0x8000, fetch_byte()))
    else
      push_call_stack(0)
    end

    # Arg count
    arg_count = calculate_arg_count(v1, v2, v3, 0)
    push_call_stack(arg_count)

    @fp = I32.sub(@csp, 4)

    # Copy locals (Spec 6.4.4)
    i = 0

    loop do
      break(if(I32.ge_u(i, num_locals)))

      local_val = 0

      v_at_least(5) do
        nil
      else
        local_val = read_word(addr)
        addr = I32.add(addr, 2)
      end

      # Initial values from arguments
      case i do
        0 -> if I32.ge_u(arg_count, 1), do: local_val = v1
        1 -> if I32.ge_u(arg_count, 2), do: local_val = v2
        2 -> if I32.ge_u(arg_count, 3), do: local_val = v3
      end

      push_call_stack(local_val)
      i = I32.add(i, 1)
    end

    @pc = addr
  end
end

defw calculate_arg_count(v1: I32, v2: I32, v3: I32, v4: I32), I32 do
  # This is a bit of a hack since we don't know which operands were omitted
  # Orb doesn't have varargs, so we pass 0 for omitted.
  # But 0 is a valid operand.
  # In practice, for now, we assume if v4 is 0 but v1,v2,v3 were provided...
  # Better to look at the caller's operand types.
  # Placeholder
  3
end

defw calculate_arg_count2(v1: I32, v2: I32, v3: I32, v4: I32, v5: I32, v6: I32, v7: I32, v8: I32),
     I32 do
  # Placeholder
  8
end

defw calculate_arg_count_generic(count: I32), I32 do
  count
end

defw do_return(val: I32) do
  # Restore state from call stack
  # Hack to avoid recursion
  _arg_count = read_call_stack(@fp, I32.add(3, 0))
  @csp = @fp

  # Arg count was at @fp + 3
  # Result info at @fp + 2
  # FP at @fp + 1
  # PC at @fp + 0

  ret_pc = read_call_stack(I32.add(@fp, 0))
  old_fp = read_call_stack(I32.add(@fp, 1))
  result_info = read_call_stack(I32.add(@fp, 2))

  @csp = @fp
  @fp = old_fp
  @pc = ret_pc

  if I32.ne(I32.band(result_info, 0x8000), 0) do
    write_variable(I32.band(result_info, 0x7FFF), val)
  end
end

# --- Objects (Spec 12) ---

defw get_object_address(obj: T.Object), T.Address do
  if I32.eq(obj, 0), do: Orb.Control.return(0)
  I32.add(@object_table_start, I32.mul(I32.sub(obj, 1), @object_entry_size))
end

defw get_object_parent(obj: T.Object), T.Object do
  addr = get_object_address(obj)
  if I32.eq(addr, 0), do: Orb.Control.return(0)

  v_at_least(4) do
    read_word(I32.add(addr, @object_parent_offset))
  else
    read_byte(I32.add(addr, @object_parent_offset))
  end
end

defw get_object_sibling(obj: T.Object), T.Object do
  addr = get_object_address(obj)
  if I32.eq(addr, 0), do: Orb.Control.return(0)

  v_at_least(4) do
    read_word(I32.add(addr, @object_sibling_offset))
  else
    read_byte(I32.add(addr, @object_sibling_offset))
  end
end

defw get_object_child(obj: T.Object), T.Object do
  addr = get_object_address(obj)
  if I32.eq(addr, 0), do: Orb.Control.return(0)

  v_at_least(4) do
    read_word(I32.add(addr, @object_child_offset))
  else
    read_byte(I32.add(addr, @object_child_offset))
  end
end

defw set_object_parent(obj: T.Object, val: T.Object) do
  addr = get_object_address(obj)

  v_at_least(4) do
    write_word(I32.add(addr, @object_parent_offset), val)
  else
    write_byte(I32.add(addr, @object_parent_offset), val)
  end
end

defw set_object_sibling(obj: T.Object, val: T.Object) do
  addr = get_object_address(obj)

  v_at_least(4) do
    write_word(I32.add(addr, @object_sibling_offset), val)
  else
    write_byte(I32.add(addr, @object_sibling_offset), val)
  end
end

defw set_object_child(obj: T.Object, val: T.Object) do
  addr = get_object_address(obj)

  v_at_least(4) do
    write_word(I32.add(addr, @object_child_offset), val)
  else
    write_byte(I32.add(addr, @object_child_offset), val)
  end
end

defw get_prop_table_address(obj: T.Object), T.Address do
  addr = get_object_address(obj)
  read_word(I32.add(addr, @object_property_table_offset))
end

defw remove_from_siblings(obj: T.Object) do
  parent = get_object_parent(obj)
  if I32.eq(parent, 0), do: Orb.Control.return()

  child = get_object_child(parent)

  if I32.eq(child, obj) do
    set_object_child(parent, get_object_sibling(obj))
  else
    prev = child
    curr = get_object_sibling(child)

    loop do
      break(if(I32.eq(curr, 0)))

      if I32.eq(curr, obj) do
        set_object_sibling(prev, get_object_sibling(obj))
        break
      end

      prev = curr
      curr = get_object_sibling(curr)
    end
  end

  set_object_parent(obj, 0)
  set_object_sibling(obj, 0)
end

defw add_to_children(parent: T.Object, obj: T.Object) do
  set_object_sibling(obj, get_object_child(parent))
  set_object_child(parent, obj)
  set_object_parent(obj, parent)
end

defw get_prop_num(addr: T.Address), I32 do
  byte = read_byte(addr)

  v_at_least(4) do
    I32.band(byte, 0x3F)
  else
    I32.band(byte, 0x1F)
  end
end

defw get_prop_header_size(addr: T.Address), I32 do
  byte = read_byte(addr)

  v_at_least(4) do
    if I32.ne(I32.band(byte, 0x80), 0) do
      2
    else
      1
    end
  else
    1
  end
end

defw get_prop_data_size(addr: T.Address), I32 do
  # addr is address of size byte
  byte = read_byte(addr)

  v_at_least(4) do
    if I32.ne(I32.band(byte, 0x80), 0) do
      # Two-byte header
      # The second byte is read separately in get_prop_header_address? No.
      # Spec 12.4.2.1.1
      len = I32.band(read_byte(I32.add(addr, 1)), 0x3F)
      if I32.eq(len, 0), do: 64, else: len
    else
      # One-byte header
      if I32.ne(I32.band(byte, 0x40), 0), do: 2, else: 1
    end
  else
    I32.add(I32.shr_u(byte, 5), 1)
  end
end

defw skip_name(addr: T.Address), T.Address do
  len = read_byte(addr)
  I32.add(addr, I32.add(1, I32.shl(len, 1)))
end

defw get_prop_header_address(obj: T.Object, prop: T.Property), T.Address do
  addr = get_prop_table_address(obj)
  addr = skip_name(addr)

  loop do
    byte = read_byte(addr)
    break(if(I32.eq(byte, 0)))

    num = get_prop_num(addr)
    if I32.eq(num, prop), do: Orb.Control.return(addr)
    if I32.lt_u(num, prop), do: Orb.Control.return(0)

    addr = I32.add(addr, I32.add(get_prop_header_size(addr), get_prop_data_size(addr)))
  end

  I32.const(0)
end

defw get_prop_address(obj: T.Object, prop: T.Property), T.Address do
  header = get_prop_header_address(obj, prop)
  if I32.eq(header, 0), do: Orb.Control.return(0)
  I32.add(header, get_prop_header_size(header))
end

defw get_prop_value(obj: T.Object, prop: T.Property), I32 do
  header = get_prop_header_address(obj, prop)

  if I32.eq(header, 0) do
    # Return default value from property defaults table
    Orb.Control.return(read_word(I32.add(@object_table_base, I32.shl(I32.sub(prop, 1), 1))))
  end

  data_addr = I32.add(header, get_prop_header_size(header))
  size = get_prop_data_size(header)

  if I32.eq(size, 1) do
    read_byte(data_addr)
  else
    read_word(data_addr)
  end
end

defw put_prop_value(obj: T.Object, prop: T.Property, val: I32) do
  header = get_prop_header_address(obj, prop)
  if I32.eq(header, 0), do: z_halt(3, @pc, 0)

  data_addr = I32.add(header, get_prop_header_size(header))
  size = get_prop_data_size(header)

  if I32.eq(size, 1) do
    write_byte(data_addr, val)
  else
    write_word(data_addr, val)
  end
end

defw get_next_prop(obj: T.Object, prop: T.Property), T.Property do
  addr = get_prop_table_address(obj)
  addr = skip_name(addr)

  if I32.eq(prop, 0) do
    Orb.Control.return(get_prop_num(addr))
  end

  loop do
    byte = read_byte(addr)
    break(if(I32.eq(byte, 0)))

    num = get_prop_num(addr)

    if I32.eq(num, prop) do
      addr = I32.add(addr, I32.add(get_prop_header_size(addr), get_prop_data_size(addr)))
      Orb.Control.return(get_prop_num(addr))
    end

    addr = I32.add(addr, I32.add(get_prop_header_size(addr), get_prop_data_size(addr)))
  end

  I32.const(0)
end

# --- Attributes ---
defw check_attribute(obj: T.Object, attr: I32), I32 do
  addr = get_object_address(obj)
  byte_addr = I32.add(addr, I32.shr_u(attr, 3))
  byte = read_byte(byte_addr)

  if I32.ne(I32.band(byte, I32.shl(1, I32.sub(7, I32.band(attr, 7)))), 0) do
    1
  else
    0
  end
end

defw set_attribute(obj: T.Object, attr: I32) do
  addr = get_object_address(obj)
  byte_addr = I32.add(addr, I32.shr_u(attr, 3))
  byte = read_byte(byte_addr)
  write_byte(byte_addr, I32.or(byte, I32.shl(1, I32.sub(7, I32.band(attr, 7)))))
end

defw clear_attribute(obj: T.Object, attr: I32) do
  addr = get_object_address(obj)
  byte_addr = I32.add(addr, I32.shr_u(attr, 3))
  byte = read_byte(byte_addr)
  write_byte(byte_addr, I32.band(byte, I32.xor(I32.shl(1, I32.sub(7, I32.band(attr, 7))), 0xFF)))
end

# --- Text (Spec 3) ---

defw print_char_wasm(char: I32) do
  if I32.eq(@stream3_active, 1) do
    # Stream to memory
    len = read_word(@stream3_table)
    write_word(I32.add(@stream3_table, I32.add(2, I32.shl(len, 1))), char)
    write_word(@stream3_table, I32.add(len, 1))
  else
    ZIO.print_char(char)
  end
end

defw do_output_stream(stream: I32, addr: T.Address) do
  if I32.eq(stream, 3) do
    @stream3_table = addr
    @stream3_active = 1
  else
    if I32.eq(stream, -3) do
      @stream3_active = 0
    end
  end
end

defw zscii_to_unicode(char: I32), I32 do
  if I32.lt_u(char, 155), do: Orb.Control.return(char)
  if I32.gt_u(char, 251), do: Orb.Control.return(char)

  if I32.ne(@unicode_table_base, 0) do
    num = read_byte(@unicode_table_base)

    if I32.ge_u(I32.sub(char, 155), num) do
      # Out of range of custom table
      Orb.Control.return(0)
    else
      Orb.Control.return(
        read_word(I32.add(@unicode_table_base, I32.add(1, I32.shl(I32.sub(char, 155), 1))))
      )
    end
  end

  # Standard table
  case char do
    # a-umlaut
    155 -> 0x00E4
    # o-umlaut
    156 -> 0x00F6
    # u-umlaut
    157 -> 0x00FC
    # A-umlaut
    158 -> 0x00C4
    # O-umlaut
    159 -> 0x00D6
    # U-umlaut
    160 -> 0x00DC
    # sz-ligature
    161 -> 0x00DF
    # >>
    162 -> 0x00BB
    # <<
    163 -> 0x00AB
    # e-umlaut
    164 -> 0x00EB
    # i-umlaut
    165 -> 0x00EF
    # y-umlaut
    166 -> 0x00FF
    # E-umlaut
    167 -> 0x00CB
    # I-umlaut
    168 -> 0x00CF
    # a-acute
    169 -> 0x00E1
    # e-acute
    170 -> 0x00E9
    # i-acute
    171 -> 0x00ED
    # o-acute
    172 -> 0x00F3
    # u-acute
    173 -> 0x00FA
    # y-acute
    174 -> 0x00FD
    # A-acute
    175 -> 0x00C1
    # E-acute
    176 -> 0x00C9
    # I-acute
    177 -> 0x00CD
    # O-acute
    178 -> 0x00D3
    # U-acute
    179 -> 0x00DA
    # Y-acute
    180 -> 0x00DD
    # a-grave
    181 -> 0x00E0
    # e-grave
    182 -> 0x00E8
    # i-grave
    183 -> 0x00EC
    # o-grave
    184 -> 0x00F2
    # u-grave
    185 -> 0x00F9
    # A-grave
    186 -> 0x00C0
    # E-grave
    187 -> 0x00C8
    # I-grave
    188 -> 0x00CC
    # O-grave
    189 -> 0x00D2
    # U-grave
    190 -> 0x00D9
    # a-circumflex
    191 -> 0x00E2
    # e-circumflex
    192 -> 0x00EA
    # i-circumflex
    193 -> 0x00EE
    # o-circumflex
    194 -> 0x00F4
    # u-circumflex
    195 -> 0x00FB
    # A-circumflex
    196 -> 0x00C2
    # E-circumflex
    197 -> 0x00CA
    # I-circumflex
    198 -> 0x00CE
    # O-circumflex
    199 -> 0x00D4
    # U-circumflex
    200 -> 0x00DB
    # a-ring
    201 -> 0x00E5
    # A-ring
    202 -> 0x00C5
    # o-slash
    203 -> 0x00F8
    # O-slash
    204 -> 0x00D8
    # a-tilde
    205 -> 0x00E3
    # n-tilde
    206 -> 0x00F1
    # o-tilde
    207 -> 0x00F5
    # A-tilde
    208 -> 0x00C3
    # N-tilde
    209 -> 0x00D1
    # O-tilde
    210 -> 0x00D5
    # ae-ligature
    211 -> 0x00E6
    # AE-ligature
    212 -> 0x00C6
    # c-cedilla
    213 -> 0x00E7
    # C-cedilla
    214 -> 0x00C7
    # thorn
    215 -> 0x00FE
    # eth
    216 -> 0x00F0
    # THORN
    217 -> 0x0DE
    # ETH
    218 -> 0x00D0
    # pound
    219 -> 0x00A3
    # oe-ligature
    220 -> 0x0153
    # OE-ligature
    221 -> 0x0152
    # inverted !
    222 -> 0x00A1
    # inverted ?
    223 -> 0x00BF
    _ -> 0
  end
end

defw unicode_to_zscii(char: I32), I32 do
  if I32.lt_u(char, 128), do: Orb.Control.return(char)

  # Custom table
  if I32.ne(@unicode_table_base, 0) do
    num = read_byte(@unicode_table_base)
    i = 0

    loop do
      break(if(I32.ge_u(i, num)))
      val = read_word(I32.add(@unicode_table_base, I32.add(1, I32.shl(i, 1))))
      if I32.eq(val, char), do: Orb.Control.return(I32.add(155, i))
      i = I32.add(i, 1)
    end
  end

  # Standard table (partial)
  case char do
    0x00E4 -> 155
    0x00F6 -> 156
    0x00FC -> 157
    # ?
    _ -> 0x3F
  end
end

defw drop_i32(val: I32) do
  nil
end

defw print_number(val: I32) do
  if I32.eq(val, 0) do
    # '0'
    print_char_wasm(48)
  else
    if I32.lt_s(val, 0) do
      # '-'
      print_char_wasm(45)
      print_number_recur(I32.mul(val, -1))
    else
      print_number_recur(val)
    end
  end
end

defw print_number_recur(val: I32) do
  if I32.ne(val, 0) do
    print_number_recur(I32.div_u(val, 10))
    print_char_wasm(I32.add(48, I32.rem_u(val, 10)))
  end
end

defw decode_zchar(z: I32) do
  # Alphabet selection (Spec 3.2)
  case @zscii_state do
    # Normal
    0 ->
      if I32.eq(z, 0) do
        # Space
        print_char_wasm(32)
      else
        if I32.lt_u(z, 4) do
          # Abbreviations (V2+)
          @abbrev_mode = z
          @zscii_state = 3
        else
          if I32.eq(z, 4) do
            @current_alphabet = 1
            @next_alphabet = 1
          else
            if I32.eq(z, 5) do
              @current_alphabet = 2
              @next_alphabet = 2
            else
              # Actual character
              # ... alphabet logic
              char = 0

              case @current_alphabet do
                0 -> char = read_byte(I32.add(0x81000, I32.sub(z, 6)))
                1 -> char = read_byte(I32.add(I32.add(0x81000, 26), I32.sub(z, 6)))
                2 -> char = read_byte(I32.add(I32.add(0x81000, 52), I32.sub(z, 6)))
              end

              if I32.eq(@current_alphabet, 2) and I32.eq(z, 6) do
                # 10-bit ZSCII follows
                @zscii_state = 1
              else
                print_char_wasm(char)
              end

              # Reset alphabet if shifted
              v_at_least(3) do
                @current_alphabet = 0
              else
                if I32.ne(@next_alphabet, -1) do
                  @current_alphabet = @next_alphabet
                  @next_alphabet = -1
                else
                  @current_alphabet = 0
                end
              end
            end
          end
        end
      end

    # ZSCII 1st half
    1 ->
      @zscii_high = I32.shl(z, 5)
      @zscii_state = 2

    # ZSCII 2nd half
    2 ->
      char = I32.or(@zscii_high, z)
      print_char_wasm(char)
      @zscii_state = 0
      @current_alphabet = 0

    # Abbreviation
    3 ->
      # Abbreviations (Spec 3.3)
      # z is the entry in the abbreviation table
      # @abbrev_mode is 1, 2, or 3
      table_entry = I32.add(I32.mul(32, I32.sub(@abbrev_mode, 1)), z)
      addr = I32.shl(read_word(I32.add(@abbreviations_base, I32.shl(table_entry, 1))), 1)

      # Save state and recurse
      old_pc = @pc
      @pc = addr
      @recursion_depth = I32.add(@recursion_depth, 1)

      # This is tricky because abbreviations can contain other abbreviations?
      # No, Spec 3.3.1: "an abbreviation string must not itself contain an abbreviation"
      # So we don't need full recursion.

      # Decode the abbreviation string at @pc
      loop do
        word = read_word(@pc)
        @pc = I32.add(@pc, 2)

        decode_zchar(I32.band(I32.shr_u(word, 10), 0x1F))
        decode_zchar(I32.band(I32.shr_u(word, 5), 0x1F))
        decode_zchar(I32.band(word, 0x1F))

        break(if(I32.ne(I32.band(word, 0x8000), 0)))
      end

      @pc = old_pc
      @zscii_state = 0
      @recursion_depth = I32.sub(@recursion_depth, 1)
  end
end

defw print_zstring(addr: T.Address) do
  old_pc = @pc
  @pc = addr

  # Save alphabet state
  old_alpha = @current_alphabet
  @current_alphabet = 0
  @zscii_state = 0

  loop do
    word = read_word(@pc)
    @pc = I32.add(@pc, 2)

    decode_zchar(I32.band(I32.shr_u(word, 10), 0x1F))
    decode_zchar(I32.band(I32.shr_u(word, 5), 0x1F))
    decode_zchar(I32.band(word, 0x1F))

    break(if(I32.ne(I32.band(word, 0x8000), 0)))
  end

  @pc = old_pc
  @current_alphabet = old_alpha
end

defw do_verify() do
  # Spec 14.13
  # Checksum of all bytes from 0x40 to story_len
  # Header 0x1C contains checksum
  expected = read_word(0x1C)
  sum = 0
  i = 0x40

  loop do
    break(if(I32.ge_u(i, @story_len)))
    sum = I32.add(sum, read_byte(i))
    i = I32.add(i, 1)
  end

  if I32.eq(I32.band(sum, 0xFFFF), expected) do
    fetch_branch(1)
  else
    fetch_branch(0)
  end
end

defw do_random(range: I32) do
  if I32.lt_s(range, 0) do
    # Seed
    @random_state = range
    fetch_result_and_store(0)
  else
    if I32.eq(range, 0) do
      # Re-seed with entropy
      @random_state = ZIO.get_random_seed()
      fetch_result_and_store(0)
    else
      # Next random
      # LCG: X = (aX + c) mod m
      @random_state = I32.add(I32.mul(@random_state, 1_103_515_245), 12345)
      val = I32.rem_u(I32.band(I32.shr_u(@random_state, 16), 0x7FFF), range)
      fetch_result_and_store(I32.add(val, 1))
    end
  end
end

defw sign_extend_16(val: I32), I32 do
  if I32.ne(I32.band(val, 0x8000), 0) do
    I32.or(val, 0xFFFF0000)
  else
    val
  end
end

defw set_font(font: I32), I32 do
  old = @current_font
  @current_font = font
  old
end

defw fetch_result_and_store_generic(val: I32) do
  # This is for opcodes that store a result
  fetch_result_and_store(val)
end

# --- Dictionary & Parsing (Spec 13) ---

defw do_scan_table(x: I32, addr: T.Address, len: I32, form: I32) do
  # Spec 15: scan_table x table len form -> (result)
  # if form is omitted, it's 0x82 (2 bytes, with bit 7 set)
  # bit 7: word (1) or byte (0)
  # bits 0-6: length of entry

  is_word = I32.ne(I32.band(form, 0x80), 0)
  entry_len = I32.band(form, 0x7F)
  if I32.eq(entry_len, 0), do: entry_len = 2

  i = 0

  loop do
    break(if(I32.ge_u(i, len)))

    val = 0

    if I32.ne(is_word, 0) do
      val = read_word(I32.add(addr, I32.mul(i, entry_len)))
    else
      val = read_byte(I32.add(addr, I32.mul(i, entry_len)))
    end

    if I32.eq(val, x) do
      fetch_result_and_store(I32.add(addr, I32.mul(i, entry_len)))
      fetch_branch(1)
      Orb.Control.return()
    end

    i = I32.add(i, 1)
  end

  fetch_result_and_store(0)
  fetch_branch(0)
end

defw read_input(text_addr: T.Address, parse_addr: T.Address) do
  # Spec 15: sread text parse (V1-V4)
  # Spec 15: aread text parse (V5+)

  # 1. Read string from host
  # 2. Tokenise

  # Placeholder for now: calls back to host
  ZIO.tokenize(text_addr, parse_addr, @dictionary_base, 0)
end

defw do_tokenise(text: T.Address, parse: T.Address, dict: T.Address, flag: I32) do
  # Spec 15: tokenise text parse dictionary flag
  if I32.eq(dict, 0), do: dict = @dictionary_base
  ZIO.tokenize(text, parse, dict, flag)
end

defw do_get_sibling(obj: T.Object) do
  sib = get_object_sibling(obj)
  fetch_result_and_store(sib)

  if I32.ne(sib, 0) do
    fetch_branch(1)
  else
    fetch_branch(0)
  end
end

defw do_get_child(obj: T.Object) do
  child = get_object_child(obj)
  fetch_result_and_store(child)

  if I32.ne(child, 0) do
    fetch_branch(1)
  else
    fetch_branch(0)
  end
end

defw do_insert_obj(obj: T.Object, dest: T.Object) do
  remove_from_siblings(obj)
  add_to_children(dest, obj)
end

defw do_remove_obj(obj: T.Object) do
  remove_from_siblings(obj)
end

defw do_set_font(font: I32) do
  old = set_font(font)
  fetch_result_and_store(old)
end

defw do_copy_table(src: T.Address, dest: T.Address, len: I32) do
  # Spec 15: copy_table first second size
  if I32.eq(dest, 0) do
    # Fill src with 0 for len bytes? No, Spec says size 0 means no-op.
    Orb.Control.return()
  end

  # Handle overlapping copy (Spec 15)
  if I32.lt_s(len, 0) do
    # Copy ABS(len) bytes, even if overlapping
    len = I32.mul(len, -1)
  end

  i = 0

  loop do
    break(if(I32.ge_u(i, len)))
    write_byte(I32.add(dest, i), read_byte(I32.add(src, i)))
    i = I32.add(i, 1)
  end
end

defw do_print_table(addr: T.Address, width: I32, height: I32, skip: I32) do
  # Spec 15: print_table zscii_text width height skip
  # (Simplified)
  i = 0

  loop do
    break(if(I32.ge_u(i, height)))
    # Print row
    j = 0

    loop do
      break(if(I32.ge_u(j, width)))
      print_char_wasm(read_byte(I32.add(addr, I32.add(I32.mul(i, I32.add(width, skip)), j))))
      j = I32.add(j, 1)
    end

    i = I32.add(i, 1)
  end
end

# --- Interpreter Core ---

defw step(export: true), I32 do
  break_if_halted()

  opc = fetch_byte()

  # Spec 4.3: Instruction forms
  if I32.lt_u(opc, 0x80) do
    # 2OP
    # Types encoded in bits 6 and 5
    types = 0

    if I32.ne(I32.band(opc, 0x40), 0),
      do: types = I32.or(types, 0x40),
      else: types = I32.or(types, 0x00)

    if I32.ne(I32.band(opc, 0x20), 0),
      do: types = I32.or(types, 0x10),
      else: types = I32.or(types, 0x00)

    execute_2op(I32.band(opc, 0x1F), types)
  else
    if I32.lt_u(opc, 0xB0) do
      # 1OP
      type = I32.band(I32.shr_u(opc, 4), 0x03)
      execute_1op(I32.band(opc, 0x0F), type)
    else
      if I32.lt_u(opc, 0xC0) do
        # 0OP
        execute_0op(I32.band(opc, 0x0F))
      else
        # VAR
        types = fetch_byte()

        if I32.ne(I32.band(opc, 0x20), 0) do
          # VAR
          execute_var(I32.band(opc, 0x1F), types)
        else
          # 2OP but with VAR type encoding
          execute_2op(I32.band(opc, 0x1F), types)
        end
      end
    end
  end

  I32.const(1)
end

defw run_steps(export: true, count: I32) do
  i = 0

  loop do
    break(if(I32.ge_u(i, count)))
    break(if(I32.ne(@halted, 0)))
    step()
    i = I32.add(i, 1)
  end
end

defwp break_if_halted() do
  if I32.ne(@halted, 0), do: Orb.Control.return()
end

defw load_story(export: true, addr: T.Address, len: I32) do
  # Only used by Generic mode. Bespoke mode uses initial_data!
  i = 0

  loop do
    break(if(I32.ge_u(i, len)))
    # This requires a host call or a buffer.
    # For now, Runner handles this by writing to memory.
    i = I32.add(i, 1)
  end
end

defw unpack_routine_address(packed: T.PackedAddress), T.Address do
  addr = I32.shl(packed, @packed_address_shift)
  I32.add(addr, @routine_offset)
end

defw unpack_string_address(packed: T.PackedAddress), T.Address do
  addr = I32.shl(packed, @packed_address_shift)
  I32.add(addr, @string_offset)
end

defw init(export: true, sp_init: I32) do
  @sp = 0
  @csp = 0
  @fp = 0
  @halted = 0
  @random_state = ZIO.get_random_seed()

  # Re-read basics from header
  @version = read_byte(0x00)
  @globals_base = read_word(0x0C)
  @dictionary_base = read_word(0x08)
  @object_table_base = read_word(0x0A)
  @static_memory_base = read_word(0x0E)
  @abbreviations_base = read_word(0x18)

  # Initial PC from header
  @pc = read_word(0x06)

  # Version-specific packed address shifts and offsets
  v_at_least(4) do
    @packed_address_shift = 2
    @object_entry_size = 14
    @object_parent_offset = 6
    @object_sibling_offset = 8
    @object_child_offset = 10
    @object_property_table_offset = 12
    @object_table_start = I32.add(@object_table_base, 126)

    v_at_least(6) do
      @routine_offset = I32.shl(read_word(0x28), 3)
      @string_offset = I32.shl(read_word(0x2A), 3)
    else
      @routine_offset = 0
      @string_offset = 0
    end
  else
    @packed_address_shift = 1
    @routine_offset = 0
    @string_offset = 0
    @object_entry_size = 9
    @object_parent_offset = 4
    @object_sibling_offset = 5
    @object_child_offset = 6
    @object_property_table_offset = 7
    @object_table_start = I32.add(@object_table_base, 62)
  end

  # Unicode table address (V5+)
  v_at_least(5) do
    addr = read_word(0x34)

    if I32.ne(addr, 0) do
      @unicode_table_base = read_word(I32.add(addr, I32.const(6)))
    end
  end
end

# Helper to get byte length of a Z-string (including 0x8000 marker)
defw get_zstring_byte_length(addr: T.Address), I32 do
  len = 0

  loop do
    word = read_word(I32.add(addr, len))
    len = I32.add(len, 2)
    break(if(I32.ne(I32.band(word, 0x8000), 0)))
  end

  len
end

# --- Debug / Getters ---
defw(get_pc(export: true), I32, do: @pc)
defw(get_sp(export: true), I32, do: @sp)
defw(set_sp(export: true, val: I32), do: @sp = val)
defw(get_fp(export: true), I32, do: @fp)
defw(get_csp(export: true), I32, do: @csp)
defw(set_pc(export: true, val: I32), do: @pc = val)
