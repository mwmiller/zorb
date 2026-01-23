defmodule Zorb.InterpreterTest.Attributes do
  use ExUnit.Case
  alias Zorb.Interpreter

  test "attribute opcodes (test_attr, set_attr, clear_attr)" do
    # V3 Object Table:
    # 31 words of defaults (62 bytes)
    # Object entries: 4 bytes attributes, 1 byte parent, 1 byte sibling, 1 byte child, 2 bytes props_addr
    # Total entry size: 9 bytes

    header =
      <<3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0x40, 0, 0, 0x08, 0x00>> <>
        :binary.copy(<<0>>, 64 - 16)

    # Object 1 at 0x40 + 62 = 0x7E
    # Attributes: 0x80 0x00 0x00 0x00 (Attr 0 set)
    object1 = <<
      0x80,
      0x00,
      0x00,
      0x00,
      0,
      0,
      0,
      # Props addr
      0,
      0x10
    >>

    code = <<
      # test_attr 1, 0 -> branch if true (next)
      0x04,
      1,
      0,
      0xC2,
      # set_attr 1, 1 (0x80 | 0x40 = 0xC0)
      0x05,
      1,
      1,
      # test_attr 1, 1 -> branch if true (next)
      0x04,
      1,
      1,
      0xC2,
      # clear_attr 1, 0 (0xC0 & ~0x80 = 0x40)
      0x06,
      1,
      0,
      # test_attr 1, 0 -> branch if false (next)
      0x04,
      1,
      0,
      0x42
    >>

    inst =
      Zorb.TestRuntime.run(Interpreter, [
        {:zio, :print_char, fn _ -> 0 end},
        {:zio, :read_char, fn -> 0 end},
        {:zio, :halt, fn _ -> 0 end}
      ])

    Zorb.TestRuntime.write_memory(inst, 0, :binary.bin_to_list(header))
    Zorb.TestRuntime.write_memory(inst, 0x7E, :binary.bin_to_list(object1))
    Zorb.TestRuntime.write_memory(inst, 0x0100, :binary.bin_to_list(code))

    Zorb.TestRuntime.call(inst, :init, 0x8000)
    Zorb.TestRuntime.call(inst, :set_pc, 0x0100)

    # 1. test_attr 1, 0 (is true)
    Zorb.TestRuntime.call(inst, :step)
    assert Zorb.TestRuntime.call(inst, :get_pc) == 0x0104

    # 2. set_attr 1, 1
    Zorb.TestRuntime.call(inst, :step)
    # Check memory at 0x7E
    attr_byte = Zorb.TestRuntime.read_memory(inst, 0x7E, 1) |> :binary.decode_unsigned()
    assert attr_byte == 0xC0

    # 3. test_attr 1, 1 (is true)
    Zorb.TestRuntime.call(inst, :step)
    assert Zorb.TestRuntime.call(inst, :get_pc) == 0x010B

    # 4. clear_attr 1, 0
    Zorb.TestRuntime.call(inst, :step)
    attr_byte = Zorb.TestRuntime.read_memory(inst, 0x7E, 1) |> :binary.decode_unsigned()
    assert attr_byte == 0x40

    # 5. test_attr 1, 0 (is false) -> branch if false to next
    Zorb.TestRuntime.call(inst, :step)
    assert Zorb.TestRuntime.call(inst, :get_pc) == 0x0112
  end

  test "test and get_prop_addr opcodes" do
    header =
      <<3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0x40, 0, 0, 0x08, 0x00>> <>
        :binary.copy(<<0>>, 64 - 16)

    # Prop Table for Obj 1 at 0x10
    # 0 words of name (0)
    # Prop 1: 1 byte data (0xAB)
    # Header: (size-1)<<5 | prop_num -> 0<<5 | 1 -> 1
    prop_table = <<0, 1, 0xAB, 0>>

    code = <<
      # test 0x0F, 0x03 -> branch if true (all bits in 0x03 are in 0x0F)
      0x09,
      0x0F,
      0x03,
      0xC2,
      # test 0x0F, 0x10 -> branch if false (0x10 is NOT in 0x0F)
      0x09,
      0x0F,
      0x10,
      0x42,
      # get_prop_addr 1, 1 -> G16
      0xD2,
      0x50,
      1,
      1,
      16
    >>

    # Object 1 at 0x40 + 62 = 0x7E
    # Props addr at offset 7 (V3)
    object1 = <<0, 0, 0, 0, 0, 0, 0, 0, 0x10>>

    inst =
      Zorb.TestRuntime.run(Interpreter, [
        {:zio, :print_char, fn _ -> 0 end},
        {:zio, :read_char, fn -> 0 end},
        {:zio, :halt, fn _ -> 0 end}
      ])

    Zorb.TestRuntime.write_memory(inst, 0, :binary.bin_to_list(header))
    Zorb.TestRuntime.write_memory(inst, 0x10, :binary.bin_to_list(prop_table))
    Zorb.TestRuntime.write_memory(inst, 0x7E, :binary.bin_to_list(object1))
    Zorb.TestRuntime.write_memory(inst, 0x0100, :binary.bin_to_list(code))

    Zorb.TestRuntime.call(inst, :init, 0x8000)
    Zorb.TestRuntime.call(inst, :set_pc, 0x0100)

    # 1. test 0x0F, 0x03 (true)
    Zorb.TestRuntime.call(inst, :step)
    assert Zorb.TestRuntime.call(inst, :get_pc) == 0x0104

    # 2. test 0x0F, 0x10 (false)
    Zorb.TestRuntime.call(inst, :step)
    assert Zorb.TestRuntime.call(inst, :get_pc) == 0x0108

    # 3. get_prop_addr 1, 1
    Zorb.TestRuntime.call(inst, :step)
    # Address should be 0x10 + 1 (name len byte) + 1 (prop header) = 0x12
    assert Zorb.TestRuntime.call(inst, :read_variable, 16) == 0x12
  end
end
