defmodule Zorb.InterpreterTest.Tokenise do
  use ExUnit.Case, async: true
  alias Zorb.Interpreter

  test "tokenise opcode" do
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

    # Dictionary at 0x0300
    # 0 separators, 4 byte entry length (minimum for V3), 1 entry
    # Entry "abc" -> zchars 6, 7, 8, padding 5, 5, 5
    # word 1: 00110 00111 01000 -> 0x18E8
    # word 2: 00101 00101 00101 (padding) -> 0x14A5 | 0x8000 -> 0x94A5
    dict = <<0, 4, 0, 1, 0x18, 0xE8, 0x94, 0xA5>>

    # Text buffer at 0x0400 (V1-4 standard format)
    # Byte 0: max length
    # Byte 1 onwards: characters typed, followed by 0.
    text_buf = <<10>> <> "abc" <> <<0>>

    # Parse buffer at 0x0500
    # Byte 0: max entries, Byte 1: actual entries
    # Each entry is 4 bytes: dict_addr (2), word_len (1), word_start (1)
    parse_buf = <<4, 0>> <> :binary.copy(<<0>>, 16)

    # Code at 0x0100: tokenise 0x0400 0x0500 0
    # 0xFB (VAR 251), types 00 00 01 11 (large, large, small, omitted) -> 0x07
    code = <<0xFB, 0x07, 0x04, 0x00, 0x05, 0x00, 0x00>>

    inst =
      OrbWasmtime.Instance.run(Interpreter, [
        {:zio, :print_char, fn _ -> 0 end}
      ])

    OrbWasmtime.Instance.write_memory(inst, 0, :binary.bin_to_list(header))
    OrbWasmtime.Instance.write_memory(inst, 0x0100, :binary.bin_to_list(code))
    OrbWasmtime.Instance.write_memory(inst, 0x0300, :binary.bin_to_list(dict))
    OrbWasmtime.Instance.write_memory(inst, 0x0400, :binary.bin_to_list(text_buf))
    OrbWasmtime.Instance.write_memory(inst, 0x0500, :binary.bin_to_list(parse_buf))

    OrbWasmtime.Instance.call(inst, :init, 0x8000)
    OrbWasmtime.Instance.call(inst, :set_pc, 0x0100)

    OrbWasmtime.Instance.call(inst, :step)

    # Check parse buffer
    # Byte 1 should be 1
    assert OrbWasmtime.Instance.read_memory(inst, 0x0501, 1) == <<1>>
    # Word at 0x0502 should be 0x0304 (dictionary entry address)
    assert OrbWasmtime.Instance.read_memory(inst, 0x0502, 2) == <<0x03, 0x04>>
    # Byte at 0x0504 should be 3 (len)
    assert OrbWasmtime.Instance.read_memory(inst, 0x0504, 1) == <<3>>
    # Byte at 0x0505 should be 1 (start index in V1-4 is characters start at 1)
    assert OrbWasmtime.Instance.read_memory(inst, 0x0505, 1) == <<1>>
  end
end
