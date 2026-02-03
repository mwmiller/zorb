defmodule Zorb.Capsule.Host do
  @moduledoc """
  WASM import definitions for the Zorb Game Capsule host interface.
  """
  use Orb.Import, name: :zio
  alias Orb.I32

  defw(print_char(char: I32))
  defw(read_char(), I32)
  defw(get_random_seed(), I32)
  defw(get_capabilities(), I32)
  defw(halt(reason: I32, pc: I32, opcode: I32))
  defw(tokenize(text: I32, parse: I32, dict: I32, flag: I32))
end
