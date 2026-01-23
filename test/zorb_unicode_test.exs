defmodule Zorb.InterpreterTest.Unicode do
  use ExUnit.Case, async: true
  alias Zorb.Interpreter

  test "print_unicode and check_unicode" do
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

    code = <<
      # check_unicode 228 -> G16
      0xBE,
      0x0C,
      0x7F,
      0xE4,
      0x10,
      # print_unicode 228
      0xBE,
      0x0B,
      0x7F,
      0xE4
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

    # Step check_unicode
    Zorb.TestRuntime.call(inst, :step)

    # check_unicode returns 3
    assert Zorb.TestRuntime.call(inst, :read_variable, 16) == 3

    # Step print_unicode
    Zorb.TestRuntime.call(inst, :step)

    assert_receive {:print_char, 0xE4}
  end
end
