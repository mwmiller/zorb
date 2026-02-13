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
  defw(log_zchar(alph: I32, zchar: I32, zscii: I32))

  # Screen Model
  defw(set_window(window_id: I32))
  defw(split_window(lines: I32))
  defw(set_cursor(line: I32, col: I32))
  defw(erase_window(window_id: I32))
  defw(erase_line(value: I32))
  defw(set_text_style(style: I32))
  defw(get_screen_size(), I32)
end
