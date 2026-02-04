defmodule Zorb.Interpreter.LogicBody do
  defmacro def_logic do
    path = Path.join(Path.dirname(__ENV__.file), "logic_body.exs")
    body = File.read!(path)
    # We parse the body into AST
    ast = Code.string_to_quoted!(body, file: path)

    # We return the AST, but we use a special trick:
    # we unquote it into a quote block that has unquote: false
    # and we also wrap the variables in var! at the AST level.

    ast =
      Macro.prewalk(ast, fn
        {name, meta, nil}
        when is_atom(name) and name not in [:I32, :T, :ZIO, :Memory, :Orb, :Bitwise] ->
          # Only wrap small, likely-local variables
          if String.length(Atom.to_string(name)) <= 4 or
               name in [
                 :types,
                 :routine,
                 :arg_count,
                 :local_val,
                 :num_locals,
                 :old_fp,
                 :ret_pc,
                 :result_info,
                 :expected,
                 :actual,
                 :target,
                 :byte_addr
               ] do
            {:var!, [], [{name, meta, nil}]}
          else
            {name, meta, nil}
          end

        other ->
          other
      end)

    quote do
      unquote(ast)
    end
  end
end
