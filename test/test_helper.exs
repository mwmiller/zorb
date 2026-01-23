ExUnit.start()

defmodule Zorb.TestRuntime do
  def run(module, imports_list) do
    imports =
      Enum.reduce(imports_list, %{}, fn {namespace, name, func}, acc ->
        ns_str = Atom.to_string(namespace)
        name_str = Atom.to_string(name)

        {params, results} = get_signature(namespace, name)

        impl_wrapper = fn _ctx, args ->
          # IO.inspect({name, args}, label: "Wasmex Callback")
          args_list =
            case args do
              l when is_list(l) -> l
              val -> [val]
            end

          res = apply(func, args_list)

          case results do
            [] -> nil
            _ -> res
          end
        end

        put_in(acc, [Access.key(ns_str, %{}), name_str], {:fn, params, results, impl_wrapper})
      end)

    wat = Orb.to_wat(module)
    {:ok, instance} = Wasmex.start_link(%{bytes: wat, imports: imports})
    instance
  end

  defp get_signature(:zio, :print_char), do: {[:i32], []}
  defp get_signature(:zio, :read_char), do: {[], [:i32]}
  defp get_signature(:zio, :halt), do: {[:i32], []}

  def write_memory(instance, offset, data) do
    {:ok, memory} = Wasmex.memory(instance)
    {:ok, store} = Wasmex.store(instance)

    bin =
      case data do
        l when is_list(l) -> :binary.list_to_bin(l)
        b -> b
      end

    Wasmex.Memory.write_binary(store, memory, offset, bin)
  end

  def read_memory(instance, offset, length) do
    {:ok, memory} = Wasmex.memory(instance)
    {:ok, store} = Wasmex.store(instance)
    Wasmex.Memory.read_binary(store, memory, offset, length)
  end

  def call(instance, name), do: call(instance, name, [])

  def call(instance, name, args) when is_list(args) do
    name_str = Atom.to_string(name)

    case Wasmex.call_function(instance, name_str, args) do
      {:ok, [res]} -> res
      {:ok, []} -> nil
      {:error, reason} -> raise "Wasm call failed: #{inspect(reason)}"
    end
  end

  def call(instance, name, arg1), do: call(instance, name, [arg1])

  def call(instance, name, arg1, arg2), do: call(instance, name, [arg1, arg2])
  def call(instance, name, arg1, arg2, arg3), do: call(instance, name, [arg1, arg2, arg3])
end
