defmodule Zorb.InterpreterTest.ObjectMovement do
  use ExUnit.Case, async: true
  alias Zorb.Interpreter

  test "object movement opcodes" do
    # Header: version 3, object table at 0x0040 (64)
    # 0x0E: Static memory base = 0x0800
    header = <<
      3,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
      # 0x08: Dictionary base
      0,
      0,
      # 0x0A: Object table = 0x0040
      0x00,
      0x40,
      0,
      0,
      # 0x0E: Static memory base
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

    # Object 1 (parent 0, sibling 0, child 2)
    # Object 2 (parent 1, sibling 0, child 0)
    # Object 3 (parent 0, sibling 0, child 0)
    # V3 Object Entry (9 bytes):
    # Attributes (4 bytes), Parent (1), Sibling (1), Child (1), Property Table (2)
    # Total 62 bytes of property defaults before objects
    # 31 property defaults (words)
    obj_table = :binary.copy(<<0, 0>>, 31)
    obj1 = <<0, 0, 0, 0, 0, 0, 2, 0x01, 0x00>>
    obj2 = <<0, 0, 0, 0, 1, 0, 0, 0x01, 0x10>>
    obj3 = <<0, 0, 0, 0, 0, 0, 0, 0x01, 0x20>>

    code = <<
      # insert_obj 2 1
      # VAR:6 (0xE6), Types: Small, Small (0x5F)
      0xE6,
      0x5F,
      2,
      1,
      # remove_obj 2
      # 1OP:9 (0x09), Small Constant (0x01) -> 10 01 1001 = 0x99
      0x99,
      2,
      # insert_obj 3 1
      0xE6,
      0x5F,
      3,
      1
    >>

    inst =
      OrbWasmtime.Instance.run(Interpreter, [
        {:zio, :print_char, fn _ -> 0 end},
        {:zio, :halt, fn _ -> 0 end}
      ])

    # Load header
    OrbWasmtime.Instance.write_memory(inst, 0, :binary.bin_to_list(header))
    # Load object table at 0x0040
    OrbWasmtime.Instance.write_memory(
      inst,
      0x0040,
      :binary.bin_to_list(obj_table <> obj1 <> obj2 <> obj3)
    )

    # Load code at PC 0x0100
    OrbWasmtime.Instance.write_memory(inst, 0x0100, :binary.bin_to_list(code))

    OrbWasmtime.Instance.call(inst, :init, 0x8000)
    OrbWasmtime.Instance.call(inst, :set_pc, 0x0100)

    # Step 1: insert_obj 2 1 (Object 2 is already child of 1, should be no change)
    OrbWasmtime.Instance.call(inst, :step)
    assert OrbWasmtime.Instance.call(inst, :get_object_child, 1) == 2

    # Step 2: remove_obj 2 (Object 1 should have no child)
    OrbWasmtime.Instance.call(inst, :step)
    assert OrbWasmtime.Instance.call(inst, :get_object_child, 1) == 0

    # Step 3: insert_obj 3 1 (Object 1 should have child 3)
    OrbWasmtime.Instance.call(inst, :step)
    assert OrbWasmtime.Instance.call(inst, :get_object_child, 1) == 3
  end
end
