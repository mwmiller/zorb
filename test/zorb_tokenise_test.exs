defmodule Zorb.InterpreterTest.Tokenise do
  use ExUnit.Case, async: true
  alias Zorb.Interpreter

  test "tokenise opcode" do
    # Header: version 3
    # 0x0E: Static memory base = 0x0800 (so everything below is writable)
    header = <<
      3,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
      # 0x08: Dictionary = 0x0300
      0x03,
      0x00,
      0,
      0,
      0,
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
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0
    >>

    # Opcode: tokenise (VAR 0x1B)
    # text_buf: 0x0400, parse_buf: 0x0500, dict_addr: 0x0300
    # VAR 0x1B is 0xFB
    # Operands: [0x0400, 0x0500, 0x0300]
    code = <<
      0xFB,
      0x03,
      0x04,
      0x00,
      0x05,
      0x00,
      0x03,
      0x00,
      0x00
    >>

    dict = <<
      1,
      ?,,
      6,
      0,
      1,
      # "cat" in Z-chars: c=8, a=6, t=25 => 00100 00110 11001 => 0x20D9
      # Word 2: 5, 5, 5 => 00101 00101 00101 => 0x14A5 | 0x8000 => 0x94A5
      0x20,
      0xD9,
      0x94,
      0xA5,
      0x00,
      0x00
    >>

    text_buf = <<10, "cat", 0>>
    parse_buf = <<4, 0, 0, 0, 0, 0>>

    inst =
      Zorb.TestRuntime.run(Interpreter, [
        {:zio, :print_char, fn _ -> 0 end},
        {:zio, :read_char, fn -> 0 end},
        {:zio, :get_random_seed, fn -> 12_345 end},
        {:zio, :get_capabilities, fn -> 0 end},
        {:zio, :halt, fn _, _, _ -> 0 end},
        {:zio, :log_step, fn _, _ -> nil end}
      ])

    # Load header
    Zorb.TestRuntime.write_memory(inst, 0, :binary.bin_to_list(header))
    # Load code at PC 0x0100
    Zorb.TestRuntime.write_memory(inst, 0x0100, :binary.bin_to_list(code))
    Zorb.TestRuntime.write_memory(inst, 0x0300, :binary.bin_to_list(dict))
    Zorb.TestRuntime.write_memory(inst, 0x0400, :binary.bin_to_list(text_buf))
    Zorb.TestRuntime.write_memory(inst, 0x0500, :binary.bin_to_list(parse_buf))

    Zorb.TestRuntime.call(inst, :init, 0x8000)
    Zorb.TestRuntime.call(inst, :set_pc, 0x0100)

    Zorb.TestRuntime.call(inst, :step)

    # Check parse buffer
    # Byte 1 should be 1
    assert Zorb.TestRuntime.read_memory(inst, 0x0501, 1) == <<1>>
    # Word at 0x0502 should be 0x0305 (dictionary entry address)
    assert Zorb.TestRuntime.read_memory(inst, 0x0502, 2) == <<0x03, 0x05>>
    # Byte at 0x0504 should be 3 (len)
    assert Zorb.TestRuntime.read_memory(inst, 0x0504, 1) == <<3>>
    # Byte at 0x0505 should be 1 (start index in V1-4 is characters start at 1)
    assert Zorb.TestRuntime.read_memory(inst, 0x0505, 1) == <<1>>
  end
end
