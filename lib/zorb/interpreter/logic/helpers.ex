defmodule Zorb.Interpreter.Logic.Helpers do
  @moduledoc """
  Compile-time helpers for the Zorb Logic macro.
  """
  alias Orb.I32

  defmacro v_at_least(v, blocks) do
    yes_block = Keyword.get(blocks, :do)
    no_block = Keyword.get(blocks, :else)

    # We look up the attribute from the module that is CURRENTLY being compiled
    story_data = Module.get_attribute(__CALLER__.module, :logic_story_data)

    if is_nil(story_data) do
      # Fallback for generic or misconfigured mode
      quote do
        if I32.ge_u(@version, unquote(v)) do
          unquote(yes_block)
        else
          unquote(no_block)
        end
      end
    else
      current_v = :binary.at(story_data, 0)

      if current_v >= v do
        yes_block
      else
        no_block
      end
    end
  end
end
