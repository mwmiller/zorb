defmodule Zorb.InterpreterTest.Font3 do
  use ExUnit.Case, async: true
  alias Zorb.Interpreter

  test "set_font opcode and character mapping" do
    header = <<
      # Version 5
      5,
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

    # EXT:4 set_font 3 -> result
    # 0xBE, 0x04, Types, Op1, Store
    # Types: Small (01) -> 0x7F
    code = <<
      # set_font 3 -> G16
      0xBE,
      0x04,
      0x7F,
      3,
      16,
      # print_char 'a' (97)
      0xE5,
      0x7F,
      97
    >>

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
        {:zio, :get_capabilities, fn -> 0x08 end},
        {:zio, :halt, fn _, _, _ -> 0 end},
        {:zio, :log_step, fn _, _ -> nil end},
        {:zio, :log_step, fn _, _ -> nil end}
      ])

    Zorb.TestRuntime.write_memory(inst, 0, :binary.bin_to_list(header))
    Zorb.TestRuntime.write_memory(inst, 0x0100, :binary.bin_to_list(code))

    Zorb.TestRuntime.call(inst, :init, 0x8000)
    Zorb.TestRuntime.call(inst, :set_pc, 0x0100)

    # Step set_font
    Zorb.TestRuntime.call(inst, :step)

    # Verify result (old font 1) stored in G16
    assert Zorb.TestRuntime.call(inst, :read_variable, 16) == 1

    # Verify Header Flags 2 (offset 0x10) has bit 3 set (0x08)
    flags2 = Zorb.TestRuntime.call(inst, :read_word, 0x10)
    assert Bitwise.band(flags2, 0x08) == 0x08

    # Step print_char 'a' -> should print Rune 'ᚪ' (0x16AA)
    Zorb.TestRuntime.call(inst, :step)
    assert_receive {:print_char, 0x16AA}

    # Test box drawings and arrows
    # print_char 33 (!) -> 0x2502
    # print_char 34 (") -> 0x2500
    # print_char 44 (,) -> 0x2191
    # print_char 46 (.) -> 0x2190
    code2 = <<
      # print_char 33
      0xE5,
      0x7F,
      33,
      # print_char 34
      0xE5,
      0x7F,
      34,
      # print_char 44
      0xE5,
      0x7F,
      44,
      # print_char 46
      0xE5,
      0x7F,
      46
    >>

    Zorb.TestRuntime.write_memory(inst, 0x0200, :binary.bin_to_list(code2))
    Zorb.TestRuntime.call(inst, :set_pc, 0x0200)

    Zorb.TestRuntime.call(inst, :step)
    assert_receive {:print_char, 0x2502}

    Zorb.TestRuntime.call(inst, :step)
    assert_receive {:print_char, 0x2500}

    Zorb.TestRuntime.call(inst, :step)
    assert_receive {:print_char, 0x2191}

    Zorb.TestRuntime.call(inst, :step)
    assert_receive {:print_char, 0x2190}

    # Exhaustive check for all mappings
    mappings = %{
      # Box Drawings
      # │
      33 => 0x2502,
      # ─
      34 => 0x2500,
      # ┌
      35 => 0x250C,
      # ┐
      36 => 0x2510,
      # └
      37 => 0x2514,
      # ┘
      38 => 0x2518,
      # ├
      39 => 0x251C,
      # ┤
      40 => 0x2524,
      # ┬
      41 => 0x252C,
      # ┴
      42 => 0x2534,
      # ┼
      43 => 0x253C,
      # Arrows
      # ↑
      44 => 0x2191,
      # ↓
      45 => 0x2193,
      # ←
      46 => 0x2190,
      # →
      47 => 0x2192,
      # Sample Runes
      # f ᚠ
      102 => 0x16A0,
      # n ᚾ
      110 => 0x16BE,
      # r ᚱ
      114 => 0x16B1,
      # s ᛋ
      115 => 0x16CB,
      # t ᛏ
      116 => 0x16CF,
      # z ᛟ
      122 => 0x16DF
    }

    for {zscii, unicode} <- mappings do
      assert Zorb.TestRuntime.call(inst, :zscii_to_unicode, zscii) == unicode
    end
  end
end
