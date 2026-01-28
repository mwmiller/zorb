defmodule Zorb.InterpreterTest do
  use ExUnit.Case
  alias Zorb.Interpreter

  test "basic add instruction" do
    # ... (existing test)
  end

  test "basic add instruction across versions" do
    # ...
  end

  test "call and return across versions" do
    for v <- [3, 4, 5] do
      header = Zorb.TestFixtures.header(v, pc: 0x0100)

      # Main: call 0x0100 (packed 0x0200 in V3, 0x0400 in V4/V5), store in G16
      packed_addr = if v <= 3, do: 0x0100, else: 0x0080
      code = Zorb.TestFixtures.call_code(v, packed_addr, 16)

      # Routine at 0x0200: 1 local, rtrue
      routine = Zorb.TestFixtures.routine_header(v, 1, [0]) <> <<0xB0>>

      inst =
        Zorb.TestRuntime.run(Interpreter, [
          {:zio, :print_char, fn _ -> 0 end},
          {:zio, :read_char, fn -> 0 end},
          {:zio, :get_random_seed, fn -> 12_345 end},
          {:zio, :get_capabilities, fn -> 0 end},
          {:zio, :halt, fn _, _, _ -> 0 end},
          {:zio, :log_step, fn _, _ -> nil end},
          {:zio, :log_step, fn _, _ -> nil end}
        ])

      Zorb.TestRuntime.write_memory(inst, 0, header)
      Zorb.TestRuntime.write_memory(inst, 0x0100, code)
      Zorb.TestRuntime.write_memory(inst, 0x0200, routine)

      Zorb.TestRuntime.call(inst, :init, 0x8000)
      Zorb.TestRuntime.call(inst, :set_pc, 0x0100)

      # Step call
      Zorb.TestRuntime.call(inst, :step)

      # Step rtrue
      Zorb.TestRuntime.call(inst, :step)

      assert Zorb.TestRuntime.call(inst, :read_variable, 16) == 1
    end
  end

  test "je instruction" do
    header = <<
      3,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      0,
      0,
      2,
      0,
      0x08,
      0x00
    >>

    # je 5, 5, branch if true, offset 4
    # Opcode 0x01, operands 5, 5, branch 0xC4
    code = <<0x01, 5, 5, 0xC4>>

    inst =
      Zorb.TestRuntime.run(Interpreter, [
        {:zio, :print_char, fn _ -> 0 end},
        {:zio, :read_char, fn -> 0 end},
        {:zio, :get_random_seed, fn -> 12_345 end},
        {:zio, :get_capabilities, fn -> 0 end},
        {:zio, :halt, fn _, _, _ -> 0 end},
        {:zio, :log_step, fn _, _ -> nil end},
        {:zio, :log_step, fn _, _ -> nil end}
      ])

    Zorb.TestRuntime.write_memory(inst, 0, :binary.bin_to_list(header))
    Zorb.TestRuntime.write_memory(inst, 0x0100, :binary.bin_to_list(code))
    Zorb.TestRuntime.call(inst, :init, 0x8000)
    Zorb.TestRuntime.call(inst, :set_pc, 0x0100)

    Zorb.TestRuntime.call(inst, :step)

    # 0x0100 + 1 (opcode) + 1 (op1) + 1 (op2) + 1 (branch byte) = 0x0104 before branch
    # Branch offset 4: @pc = 0x0104 + 4 - 2 = 0x0106
    assert Zorb.TestRuntime.call(inst, :get_pc) == 0x0106
  end

  test "1OP large constant and jz" do
    header = <<
      3,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      0,
      0,
      2,
      0,
      0x08,
      0x00
    >>

    # jz 0, branch if true, offset 2
    # 1OP: 10 (Large) 00 (jz) -> 0x80 | 0x00 | 0x00 = 0x80
    # Operand: 0x0000 (Large constant)
    # Branch: 0xC2 (True, offset 2)
    code = <<0x80, 0x00, 0x00, 0xC2>>

    inst =
      Zorb.TestRuntime.run(Interpreter, [
        {:zio, :print_char, fn _ -> 0 end},
        {:zio, :read_char, fn -> 0 end},
        {:zio, :get_random_seed, fn -> 12_345 end},
        {:zio, :get_capabilities, fn -> 0 end},
        {:zio, :halt, fn _, _, _ -> 0 end},
        {:zio, :log_step, fn _, _ -> nil end},
        {:zio, :log_step, fn _, _ -> nil end}
      ])

    Zorb.TestRuntime.write_memory(inst, 0, :binary.bin_to_list(header))
    Zorb.TestRuntime.write_memory(inst, 0x0100, :binary.bin_to_list(code))
    Zorb.TestRuntime.call(inst, :init, 0x8000)
    Zorb.TestRuntime.call(inst, :set_pc, 0x0100)

    Zorb.TestRuntime.call(inst, :step)

    # 0x0100 + 1 (opcode) + 2 (large op) + 1 (branch byte) = 0x0104 before branch
    # Branch offset 2: @pc = 0x0104 + 2 - 2 = 0x0104
    assert Zorb.TestRuntime.call(inst, :get_pc) == 0x0104
  end

  test "2OP with variable and false branch" do
    header = <<
      3,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      0,
      0,
      2,
      0,
      0x08,
      0x00
    >>

    # je L01, 5, branch if false, offset 3
    # 0x61, 1, 5, 0x43
    code = <<0x61, 1, 5, 0x43>>

    inst =
      Zorb.TestRuntime.run(Interpreter, [
        {:zio, :print_char, fn _ -> 0 end},
        {:zio, :read_char, fn -> 0 end},
        {:zio, :get_random_seed, fn -> 12_345 end},
        {:zio, :get_capabilities, fn -> 0 end},
        {:zio, :halt, fn _, _, _ -> 0 end},
        {:zio, :log_step, fn _, _ -> nil end},
        {:zio, :log_step, fn _, _ -> nil end}
      ])

    Zorb.TestRuntime.write_memory(inst, 0, :binary.bin_to_list(header))
    Zorb.TestRuntime.write_memory(inst, 0x0100, :binary.bin_to_list(code))
    Zorb.TestRuntime.call(inst, :init, 0x8000)
    Zorb.TestRuntime.call(inst, :set_pc, 0x0100)

    Zorb.TestRuntime.call(inst, :write_variable, 1, 10)

    Zorb.TestRuntime.call(inst, :step)

    # 0x0100 + 1 (opcode) + 1 (op1 var) + 1 (op2 small) + 1 (branch byte) = 0x0104 before branch
    # 10 != 5 (False). Branch "if false" (bit 7=0) -> do branch.
    # Branch offset 3: @pc = 0x0104 + 3 - 2 = 0x0105
    assert Zorb.TestRuntime.call(inst, :get_pc) == 0x0105
  end

  test "negative branch offset" do
    header = <<
      3,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      0,
      0,
      2,
      0,
      0x08,
      0x00
    >>

    # jz 0, branch if true, offset -2 (long branch)
    # code = <<0x80, 0x00, 0x00, 0xBF, 0xFE>>
    code = <<0x80, 0x00, 0x00, 0xBF, 0xFE>>

    inst =
      Zorb.TestRuntime.run(Interpreter, [
        {:zio, :print_char, fn _ -> 0 end},
        {:zio, :read_char, fn -> 0 end},
        {:zio, :get_random_seed, fn -> 12_345 end},
        {:zio, :get_capabilities, fn -> 0 end},
        {:zio, :halt, fn _, _, _ -> 0 end},
        {:zio, :log_step, fn _, _ -> nil end},
        {:zio, :log_step, fn _, _ -> nil end}
      ])

    Zorb.TestRuntime.write_memory(inst, 0, :binary.bin_to_list(header))
    Zorb.TestRuntime.write_memory(inst, 0x0100, :binary.bin_to_list(code))
    Zorb.TestRuntime.call(inst, :init, 0x8000)
    Zorb.TestRuntime.call(inst, :set_pc, 0x0100)

    Zorb.TestRuntime.call(inst, :step)

    # 0x0100 + 1 (opcode) + 2 (large op) + 2 (long branch) = 0x0105 before branch
    # Offset -2: @pc = 0x0105 - 2 - 2 = 0x0101
    assert Zorb.TestRuntime.call(inst, :get_pc) == 0x0101
  end

  test "call and return" do
    header = <<
      3,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      0,
      0,
      2,
      0,
      0x08,
      0x00
    >>

    # Main code at 0x0100: call routine at 0x0200, store in G16
    # 0x0200 packed in V3 is 0x0100
    # VAR 0: call. opcode 0. types_byte: 00 (Large) 11 (Omit) 11 11 -> 0x3F
    # call 0x0100 (packed 0x0200), store in G16
    code = <<0xE0, 0x3F, 0x01, 0x00, 16>>

    # Routine at 0x0200:
    # 1 local variable
    # rtrue (return 1)
    # 1 local, rtrue (0xB0 is 0OP opcode 0)
    routine = <<1, 0, 0, 0xB0>>

    inst =
      Zorb.TestRuntime.run(Interpreter, [
        {:zio, :print_char, fn _ -> 0 end},
        {:zio, :read_char, fn -> 0 end},
        {:zio, :get_random_seed, fn -> 12_345 end},
        {:zio, :get_capabilities, fn -> 0 end},
        {:zio, :halt, fn _, _, _ -> 0 end},
        {:zio, :log_step, fn _, _ -> nil end},
        {:zio, :log_step, fn _, _ -> nil end}
      ])

    Zorb.TestRuntime.write_memory(inst, 0, :binary.bin_to_list(header))
    Zorb.TestRuntime.write_memory(inst, 0x0100, :binary.bin_to_list(code))
    Zorb.TestRuntime.write_memory(inst, 0x0200, :binary.bin_to_list(routine))
    Zorb.TestRuntime.call(inst, :init, 0x8000)
    Zorb.TestRuntime.call(inst, :set_pc, 0x0100)

    # Step call
    Zorb.TestRuntime.call(inst, :step)
    # Routine address 0x0200. Read locals count (1 byte) -> 0x0201.
    # Read initial values for 1 local (2 bytes in V3) -> 0x0203.
    assert Zorb.TestRuntime.call(inst, :get_pc) == 0x0203

    # Step rtrue
    Zorb.TestRuntime.call(inst, :step)
    # Returns to PC after the call instruction.
    # call 0x0100 (5 bytes) -> 0x0105
    assert Zorb.TestRuntime.call(inst, :get_pc) == 0x0105
    assert Zorb.TestRuntime.call(inst, :read_variable, 16) == 1
  end

  test "print_char instruction" do
    header = <<
      3,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      0,
      0,
      2,
      0,
      0x08,
      0x00
    >>

    # VAR 5: print_char. opcode 5. types_byte: 01 (Small) 11 11 11 -> 0x7F
    # code: 0xE5 (VAR 5) 0x7F (Small) 65 ('A')
    code = <<0xE5, 0x7F, 65>>

    parent = self()

    inst =
      Zorb.TestRuntime.run(Interpreter, [
        {:zio, :print_char,
         fn char ->
           send(parent, {:print_char, char})
           0
         end},
        {:zio, :read_char, fn -> 0 end},
        {:zio, :get_random_seed, fn -> 12_345 end},
        {:zio, :get_capabilities, fn -> 0 end},
        {:zio, :halt, fn _, _, _ -> 0 end},
        {:zio, :log_step, fn _, _ -> nil end},
        {:zio, :log_step, fn _, _ -> nil end}
      ])

    Zorb.TestRuntime.write_memory(inst, 0, :binary.bin_to_list(header))
    Zorb.TestRuntime.write_memory(inst, 0x0100, :binary.bin_to_list(code))
    Zorb.TestRuntime.call(inst, :init, 0x8000)
    Zorb.TestRuntime.call(inst, :set_pc, 0x0100)

    Zorb.TestRuntime.call(inst, :step)

    assert_receive {:print_char, 65}
  end

  test "print (z-string) instruction" do
    header = <<
      3,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      0,
      0,
      2,
      0,
      0x08,
      0x00
    >>

    # 0OP 2: print. opcode 2.
    # code: 0xB2 (0OP 2)
    # Z-string for "abc":
    # 5-bit codes: 'a'=6, 'b'=7, 'c'=8
    # word: 0 (bit 15) | 6<<10 | 7<<5 | 8 = 0x18E8
    # mark as done (bit 15=1) -> 0x98E8
    code = <<0xB2, 0x98, 0xE8>>

    parent = self()

    inst =
      Zorb.TestRuntime.run(Interpreter, [
        {:zio, :print_char,
         fn char ->
           send(parent, {:print_char, char})
           0
         end},
        {:zio, :read_char, fn -> 0 end},
        {:zio, :get_random_seed, fn -> 12_345 end},
        {:zio, :get_capabilities, fn -> 0 end},
        {:zio, :halt, fn _, _, _ -> 0 end},
        {:zio, :log_step, fn _, _ -> nil end},
        {:zio, :log_step, fn _, _ -> nil end}
      ])

    Zorb.TestRuntime.write_memory(inst, 0, :binary.bin_to_list(header))
    Zorb.TestRuntime.write_memory(inst, 0x0100, :binary.bin_to_list(code))
    Zorb.TestRuntime.call(inst, :init, 0x8000)
    Zorb.TestRuntime.call(inst, :set_pc, 0x0100)

    Zorb.TestRuntime.call(inst, :step)

    # 'a'
    assert_receive {:print_char, 97}
    # 'b'
    assert_receive {:print_char, 98}
    # 'c'
    assert_receive {:print_char, 99}
  end

  test "object table navigation" do
    # V3 header
    # 0x0A: Object Table = 0x0200
    header = <<
      3,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      0x02,
      0x00,
      2,
      0,
      0x08,
      0x00
    >>

    # Object Table at 0x0200:
    # 31 words of defaults (62 bytes) -> 0x023E
    # Object 1 (at 0x023E): Parent=0, Sibling=0, Child=2 (offset 6)
    # Object 2 (at 0x0247): Parent=1, Sibling=3, Child=0
    # Object 3 (at 0x0250): Parent=1, Sibling=0, Child=0

    # 62 bytes of zeros for defaults
    defaults = :binary.copy(<<0>>, 62)
    obj1 = <<0, 0, 0, 0, 0, 0, 2, 0, 0>>
    obj2 = <<0, 0, 0, 0, 1, 3, 0, 0, 0>>
    obj3 = <<0, 0, 0, 0, 1, 0, 0, 0, 0>>

    # code: get_child 1 -> store in G16, branch if true (offset 4)
    # 1OP: 0x80 | 0x10 (Small) | 0x02 (get_child) -> 0x92
    code = <<0x92, 1, 16, 0xC4>>

    inst =
      Zorb.TestRuntime.run(Interpreter, [
        {:zio, :print_char, fn _ -> 0 end},
        {:zio, :read_char, fn -> 0 end},
        {:zio, :get_random_seed, fn -> 12_345 end},
        {:zio, :get_capabilities, fn -> 0 end},
        {:zio, :halt, fn _, _, _ -> 0 end},
        {:zio, :log_step, fn _, _ -> nil end},
        {:zio, :log_step, fn _, _ -> nil end}
      ])

    Zorb.TestRuntime.write_memory(inst, 0, :binary.bin_to_list(header))

    Zorb.TestRuntime.write_memory(
      inst,
      0x0200,
      :binary.bin_to_list(defaults <> obj1 <> obj2 <> obj3)
    )

    Zorb.TestRuntime.write_memory(inst, 0x0100, :binary.bin_to_list(code))
    Zorb.TestRuntime.call(inst, :init, 0x8000)
    Zorb.TestRuntime.call(inst, :set_pc, 0x0100)

    Zorb.TestRuntime.call(inst, :step)

    assert Zorb.TestRuntime.call(inst, :read_variable, 16) == 2
    # 0x0100 + 2 (instr) + 1 (res var) + 1 (branch) + 4 - 2 = 0x0106
    assert Zorb.TestRuntime.call(inst, :get_pc) == 0x0106
  end

  @tag :abbrev
  test "z-string abbreviation" do
    header = <<
      3,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      0,
      0,
      2,
      0,
      0x08,
      0x00,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      # 0x18: Abbreviations = 0x0300
      0x03,
      0x00,
      0,
      0
    >>

    # Abbreviations Table at 0x0300:
    # 96 entries, each 1 word (packed address).
    # Entry 0: packed 0x0100 -> 0x0200
    abbrev_table = <<0x01, 0x00>> <> :binary.copy(<<0>>, 190)

    # String at 0x0200: "abc"
    abbrev_string = <<0x98, 0xE8>>

    # Main code at 0x0100: print abbrev 0
    # 0x01 (Abbrev set 1) 0x00 (Entry 0) -> bits 00001 00000 -> 0x0400
    # Next char 'z' (31) -> 0x041F
    # code: 0xB2 (print) 0x84, 0x1F (bit 15=1)
    code = <<0xB2, 0x84, 0x1F>>

    parent = self()

    inst =
      Zorb.TestRuntime.run(Interpreter, [
        {:zio, :print_char,
         fn char ->
           send(parent, {:print_char, char})
           0
         end},
        {:zio, :read_char, fn -> 0 end},
        {:zio, :get_random_seed, fn -> 12_345 end},
        {:zio, :get_capabilities, fn -> 0 end},
        {:zio, :halt, fn _, _, _ -> 0 end},
        {:zio, :log_step, fn _, _ -> nil end},
        {:zio, :log_step, fn _, _ -> nil end}
      ])

    Zorb.TestRuntime.write_memory(inst, 0, :binary.bin_to_list(header))
    Zorb.TestRuntime.write_memory(inst, 0x0100, :binary.bin_to_list(code))
    Zorb.TestRuntime.write_memory(inst, 0x0200, :binary.bin_to_list(abbrev_string))
    Zorb.TestRuntime.write_memory(inst, 0x0300, :binary.bin_to_list(abbrev_table))
    Zorb.TestRuntime.call(inst, :init, 0x8000)
    Zorb.TestRuntime.call(inst, :set_pc, 0x0100)

    Zorb.TestRuntime.call(inst, :step)

    # 'a'
    assert_receive {:print_char, 97}
    # 'b'
    assert_receive {:print_char, 98}
    # 'c'
    assert_receive {:print_char, 99}
    # 'z'
    assert_receive {:print_char, 122}
  end
end
