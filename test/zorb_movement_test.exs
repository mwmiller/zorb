defmodule Zorb.InterpreterTest.ObjectMovement do
  use ExUnit.Case, async: true
  alias Zorb.Interpreter

  test "object movement opcodes" do
    # Header: version 3, object table at 0x0040 (64)
    header = <<
      3,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
      # 0x0A: Object table = 0x0040
      0,
      0,
      0x00,
      0x40,
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

    # V3 Object Table at 0x0040
    # 31 default properties (62 bytes) -> ends at 64 + 62 = 126
    # Obj 1 (starts at 126): parent 0, sibling 0, child 2
    # Obj 2 (starts at 135): parent 1, sibling 3, child 0
    # Obj 3 (starts at 144): parent 1, sibling 0, child 0
    defaults = :binary.copy(<<0>>, 62)
    obj1 = <<0, 0, 0, 0, 0, 0, 2, 0, 0x80>>
    obj2 = <<0, 0, 0, 0, 1, 3, 0, 0, 0x90>>
    obj3 = <<0, 0, 0, 0, 1, 0, 0, 0, 0xA0>>

    # Code at 0x0100
    # 1. remove_obj 2 (1OP 9, small type -> 0x99)
    # 2. insert_obj 3 2 (VAR 6, types small, small -> 0xE6, 0x5F)
    code = <<0x99, 0x02, 0xE6, 0x5F, 0x03, 0x02>>

    inst =
      OrbWasmtime.Instance.run(Interpreter, [
        {:zio, :print_char, fn _ -> 0 end}
      ])

    OrbWasmtime.Instance.write_memory(inst, 0, :binary.bin_to_list(header))

    OrbWasmtime.Instance.write_memory(
      inst,
      0x40,
      :binary.bin_to_list(defaults <> obj1 <> obj2 <> obj3)
    )

    OrbWasmtime.Instance.write_memory(inst, 0x0100, :binary.bin_to_list(code))

    OrbWasmtime.Instance.call(inst, :init, 0x8000)
    OrbWasmtime.Instance.call(inst, :set_pc, 0x0100)

    # Step 1: remove_obj 2
    OrbWasmtime.Instance.call(inst, :step)
    assert OrbWasmtime.Instance.call(inst, :get_object_child, 1) == 3
    assert OrbWasmtime.Instance.call(inst, :get_object_parent, 2) == 0

    # Step 2: insert_obj 3 2
    OrbWasmtime.Instance.call(inst, :step)
    assert OrbWasmtime.Instance.call(inst, :get_object_child, 2) == 3
    assert OrbWasmtime.Instance.call(inst, :get_object_parent, 3) == 2
    assert OrbWasmtime.Instance.call(inst, :get_object_child, 1) == 0
  end
end
