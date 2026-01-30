defmodule Zorb.Phase0Test do
  use ExUnit.Case
  alias Zorb.Interpreter

  test "dec_chk instruction" do
    header = Zorb.TestFixtures.header(3, pc: 0x0100)
    # dec_chk L01, 5, branch if true (val < 5), offset 4
    # 0 | 0 | 0 | 00100 = 0x04
    code = <<0x04, 1, 5, 0xC4>>

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
    Zorb.TestRuntime.call(inst, :init, 0x8000)
    Zorb.TestRuntime.call(inst, :set_pc, 0x0100)

    # Set L01 to 6
    Zorb.TestRuntime.call(inst, :write_variable, 1, 6)

    # Step 1: 6 -> 5. 5 < 5 is False. No branch.
    Zorb.TestRuntime.call(inst, :step)
    assert Zorb.TestRuntime.call(inst, :read_variable, 1) == 5
    assert Zorb.TestRuntime.call(inst, :get_pc) == 0x0104

    # Step 2: 5 -> 4. 4 < 5 is True. Branch offset 4.
    Zorb.TestRuntime.call(inst, :set_pc, 0x0100)
    Zorb.TestRuntime.call(inst, :step)
    assert Zorb.TestRuntime.call(inst, :read_variable, 1) == 4
    # PC = 0x0104 + 4 - 2 = 0x0106
    assert Zorb.TestRuntime.call(inst, :get_pc) == 0x0106
  end

  test "inc_chk instruction" do
    header = Zorb.TestFixtures.header(3, pc: 0x0100)
    # inc_chk L01, 5, branch if true (val > 5), offset 4
    # 0 | 0 | 0 | 00101 = 0x05
    code = <<0x05, 1, 5, 0xC4>>

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
    Zorb.TestRuntime.call(inst, :init, 0x8000)
    Zorb.TestRuntime.call(inst, :set_pc, 0x0100)

    # Set L01 to 4
    Zorb.TestRuntime.call(inst, :write_variable, 1, 4)

    # Step 1: 4 -> 5. 5 > 5 is False. No branch.
    Zorb.TestRuntime.call(inst, :step)
    assert Zorb.TestRuntime.call(inst, :read_variable, 1) == 5
    assert Zorb.TestRuntime.call(inst, :get_pc) == 0x0104

    # Step 2: 5 -> 6. 6 > 5 is True. Branch offset 4.
    Zorb.TestRuntime.call(inst, :set_pc, 0x0100)
    Zorb.TestRuntime.call(inst, :step)
    assert Zorb.TestRuntime.call(inst, :read_variable, 1) == 6
    assert Zorb.TestRuntime.call(inst, :get_pc) == 0x0106
  end

  test "jin instruction" do
    header = Zorb.TestFixtures.header(3, pc: 0x0100, objects: 0x0200)
    # jin 2, 1, branch if true, offset 4
    # 0 | 0 | 0 | 00110 = 0x06
    code = <<0x06, 2, 1, 0xC4>>

    # Object Table at 0x0200:
    # 31 words of defaults (62 bytes) -> 0x023E
    # Object 1 (at 0x023E): Parent=0, Sibling=0, Child=2
    # Object 2 (at 0x0247): Parent=1, Sibling=0, Child=0
    defaults = :binary.copy(<<0>>, 62)
    obj1 = <<0, 0, 0, 0, 0, 0, 2, 0, 0>>
    obj2 = <<0, 0, 0, 0, 1, 0, 0, 0, 0>>

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
    Zorb.TestRuntime.write_memory(inst, 0x0200, defaults <> obj1 <> obj2)
    Zorb.TestRuntime.call(inst, :init, 0x8000)
    Zorb.TestRuntime.call(inst, :set_pc, 0x0100)

    Zorb.TestRuntime.call(inst, :step)
    # Object 2's parent is 1. 1 == 1 is True. Branch.
    assert Zorb.TestRuntime.call(inst, :get_pc) == 0x0106
  end

  test "random instruction" do
    header = Zorb.TestFixtures.header(3, pc: 0x0100)
    # random 10 -> G16
    # VAR:7 -> 0xE7. types_byte: 01 (Small) 11 11 11 -> 0x7F
    code = <<0xE7, 0x7F, 10, 16>>

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
    Zorb.TestRuntime.call(inst, :init, 0x8000)
    Zorb.TestRuntime.call(inst, :set_pc, 0x0100)

    Zorb.TestRuntime.call(inst, :step)
    res = Zorb.TestRuntime.call(inst, :read_variable, 16)
    assert res >= 1 and res <= 10
  end

  test "verify instruction" do
    # Checksum at 0x1C. Sum of bytes from 0x40 to end.
    # Story length 0x50. Bytes 0x40-0x4F: all 1s (16 bytes) -> sum 16.
    header = Zorb.TestFixtures.header(3, pc: 0x0100)
    # Set checksum at 0x1C
    header = :binary.bin_to_list(header)
    header = List.replace_at(header, 0x1A, 0)
    # 0x28 * 2 = 0x50 bytes
    header = List.replace_at(header, 0x1B, 0x28)
    header = List.replace_at(header, 0x1C, 0)
    header = List.replace_at(header, 0x1D, 16)

    # 0OP:13 -> 10 11 1101 = 0xBD
    # verify, branch if true, offset 4
    code = <<0xBD, 0xC4>>

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

    # First set @story_len via load_story. This clears/fills memory.
    Zorb.TestRuntime.call(inst, :load_story, 0, 0x50)

    Zorb.TestRuntime.write_memory(inst, 0, :binary.list_to_bin(header))
    Zorb.TestRuntime.write_memory(inst, 0x0100, code)
    # Fill 0x40-0x50 with 1s
    Zorb.TestRuntime.write_memory(inst, 0x40, :binary.copy(<<1>>, 16))

    Zorb.TestRuntime.call(inst, :init, 0x8000)
    Zorb.TestRuntime.call(inst, :set_pc, 0x0100)

    Zorb.TestRuntime.call(inst, :step)
    # Sum is 16, matches 0x1C. True. Branch.
    # 0x0100 + 1 (opcode) + 1 (branch) = 0x0102. Branch 4-2=2 -> 0x0104.
    assert Zorb.TestRuntime.call(inst, :get_pc) == 0x0104
  end

  test "scan_table instruction" do
    header = Zorb.TestFixtures.header(3, pc: 0x0100)
    # scan_table 0x1234, 0x0200, 5, 0x82 -> G16
    # VAR:23 -> 0xF7. types_byte: 00 (Large) 00 (Large) 01 (Small) 01 (Small) -> 0x05
    code = <<0xF7, 0x05, 0x12, 0x34, 0x02, 0x00, 5, 0x82, 16>>

    # Table at 0x0200: [0x1111, 0x2222, 0x1234, 0x4444, 0x5555]
    table = <<0x11, 0x11, 0x22, 0x22, 0x12, 0x34, 0x44, 0x44, 0x55, 0x55>>

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
    Zorb.TestRuntime.write_memory(inst, 0x0200, table)
    Zorb.TestRuntime.call(inst, :init, 0x8000)
    Zorb.TestRuntime.call(inst, :set_pc, 0x0100)

    Zorb.TestRuntime.call(inst, :step)
    # Found at 0x0200 + 2*2 = 0x0204
    assert Zorb.TestRuntime.call(inst, :read_variable, 16) == 0x0204
  end

  test "log_shift and art_shift" do
    header = Zorb.TestFixtures.header(5, pc: 0x0100)

    # EXT:2 log_shift 1, 2 -> G16 (4)
    # 0xBE 0x02 0x5F 1 2 16
    code_log = <<0xBE, 0x02, 0x5F, 1, 2, 16>>

    # EXT:3 art_shift -4, -1 -> G17 (-2)
    # -4 is 0xFFFC. -1 is 0xFFFF.
    # 0xBE 0x03 0x0F 0xFF, 0xFC, 0xFF, 0xFF, 17
    code_art = <<0xBE, 0x03, 0x0F, 0xFF, 0xFC, 0xFF, 0xFF, 17>>

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
    Zorb.TestRuntime.write_memory(inst, 0x0100, code_log)
    Zorb.TestRuntime.write_memory(inst, 0x0106, code_art)
    Zorb.TestRuntime.call(inst, :init, 0x8000)
    Zorb.TestRuntime.call(inst, :set_pc, 0x0100)

    Zorb.TestRuntime.call(inst, :step)
    assert Zorb.TestRuntime.call(inst, :read_variable, 16) == 4

    Zorb.TestRuntime.call(inst, :step)
    assert Zorb.TestRuntime.call(inst, :read_variable, 17) == 0xFFFE
  end
end
