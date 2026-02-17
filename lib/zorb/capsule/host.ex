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
  defw(set_colour(foreground: I32, background: I32))
  defw(sound_effect(number: I32))
  defw(get_screen_size(), I32)

  # Save/Restore
  defw(save(pc: I32, sp: I32, fp: I32, csp: I32, random_state: I32), I32)
  defw(restore(), I32)
  defw(get_restored_pc(), I32)
  defw(get_restored_sp(), I32)
  defw(get_restored_fp(), I32)
  defw(get_restored_csp(), I32)
  defw(get_restored_random_state(), I32)

  # Undo
  defw(save_undo(pc: I32, sp: I32, fp: I32, csp: I32, random_state: I32), I32)
  defw(restore_undo(), I32)
  defw(get_undone_pc(), I32)
  defw(get_undone_sp(), I32)
  defw(get_undone_fp(), I32)
  defw(get_undone_csp(), I32)
  defw(get_undone_random_state(), I32)

  # Interrupts
  defw(check_interrupt(), I32)
end
