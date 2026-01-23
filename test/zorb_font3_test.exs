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
        {:zio, :halt, fn _ -> 0 end}
      ])

    Zorb.TestRuntime.write_memory(inst, 0, :binary.bin_to_list(header))
    Zorb.TestRuntime.write_memory(inst, 0x0100, :binary.bin_to_list(code))

    Zorb.TestRuntime.call(inst, :init, 0x8000)
    Zorb.TestRuntime.call(inst, :set_pc, 0x0100)

    # Step set_font
    Zorb.TestRuntime.call(inst, :step)

    # Verify result (old font 1) stored in G16
    assert Zorb.TestRuntime.call(inst, :read_variable, 16) == 1

    # Step print_char 'a' -> should print Rune 'ᚪ' (0x16AA)
    Zorb.TestRuntime.call(inst, :step)

    assert_receive {:print_char, 0x16AA}
  end
end
