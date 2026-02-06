defmodule Zorb.Capsule.Host do
  @moduledoc false
  use Orb.Import, name: :zio

  defw(print_char(char: I32))
  defw(print_num(num: I32))
  defw(read_char(), I32)
  defw(get_random(max: I32), I32)
  defw(get_random_seed(), I32)
  defw(get_capabilities(), I32)
  defw(halt(reason: I32, pc: I32, opcode: I32))
  defw(tokenize(text: I32, parse: I32, dict: I32, flag: I32))
  defw(log_step(tick: I32, pc: I32, opcode: I32))
end
