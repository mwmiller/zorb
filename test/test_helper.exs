ExUnit.start()

defmodule Zorb.TestRuntime do
  @moduledoc false

  def default_zio_imports do
    [
      {:zio, :print_char, fn _ -> 0 end},
      {:zio, :read_char, fn -> 0 end},
      {:zio, :get_random_seed, fn -> 12_345 end},
      {:zio, :get_capabilities, fn -> 0 end},
      {:zio, :halt, fn _, _, _ -> 0 end},
      {:zio, :log_step, fn _, _ -> nil end},
      # Tokenize is now in WASM only (bespoke assembler)
      # {:zio, :tokenize, &Zorb.Tokeniser.tokenize/5}
    ]
  end

  def run(module, imports_list) do
    # Map of provided imports
    provided = for {ns, name, func} <- imports_list, into: %{}, do: {{ns, name}, func}

    # Start with defaults and override with provided
    merged =
      Enum.map(default_zio_imports(), fn {ns, name, default_func} ->
        func = Map.get(provided, {ns, name}, default_func)
        {ns, name, func}
      end)

    # Add any extra provided imports that are not in defaults
    extra =
      for {{ns, name}, func} <- provided,
          not Enum.any?(default_zio_imports(), fn {dns, dname, _} ->
            dns == ns and dname == name
          end),
          do: {ns, name, func}

    imports = Enum.reduce(merged ++ extra, %{}, &add_import/2)

    wat = Orb.to_wat(module)
    {:ok, instance} = Wasmex.start_link(%{bytes: wat, imports: imports})
    instance
  end

  defp add_import({namespace, name, func}, acc) do
    ns_str = Atom.to_string(namespace)
    name_str = Atom.to_string(name)

    {params, results} = get_signature(namespace, name)

    impl_wrapper = build_impl_wrapper(params, results, func)

    put_in(acc, [Access.key(ns_str, %{}), name_str], {:fn, params, results, impl_wrapper})
  end

  defp build_impl_wrapper(params, results, func) do
    arity =
      case :erlang.fun_info(func)[:arity] do
        :undefined -> 0
        a -> a
      end

    expected_arity = length(params)

    if arity == expected_arity + 1 do
      build_context_wrapper(expected_arity, results, func)
    else
      build_simple_wrapper(expected_arity, results, func)
    end
  end

  defp build_context_wrapper(0, results, func) do
    fn ctx ->
      res = func.(ctx)
      if results == [], do: nil, else: res
    end
  end

  defp build_context_wrapper(1, results, func) do
    fn ctx, arg1 ->
      res = func.(ctx, arg1)
      if results == [], do: nil, else: res
    end
  end

  defp build_context_wrapper(2, results, func) do
    fn ctx, arg1, arg2 ->
      res = func.(ctx, arg1, arg2)
      if results == [], do: nil, else: res
    end
  end

  defp build_context_wrapper(3, results, func) do
    fn ctx, arg1, arg2, arg3 ->
      res = func.(ctx, arg1, arg2, arg3)
      if results == [], do: nil, else: res
    end
  end

  defp build_context_wrapper(4, results, func) do
    fn ctx, arg1, arg2, arg3, arg4 ->
      res = func.(ctx, arg1, arg2, arg3, arg4)
      if results == [], do: nil, else: res
    end
  end

  defp build_simple_wrapper(0, results, func) do
    fn _ctx ->
      res = func.()
      if results == [], do: nil, else: res
    end
  end

  defp build_simple_wrapper(1, results, func) do
    fn _ctx, arg1 ->
      res = func.(arg1)
      if results == [], do: nil, else: res
    end
  end

  defp build_simple_wrapper(2, results, func) do
    fn _ctx, arg1, arg2 ->
      res = func.(arg1, arg2)
      if results == [], do: nil, else: res
    end
  end

  defp build_simple_wrapper(3, results, func) do
    fn _ctx, arg1, arg2, arg3 ->
      res = func.(arg1, arg2, arg3)
      if results == [], do: nil, else: res
    end
  end

  defp build_simple_wrapper(4, results, func) do
    fn _ctx, arg1, arg2, arg3, arg4 ->
      res = func.(arg1, arg2, arg3, arg4)
      if results == [], do: nil, else: res
    end
  end

  defp get_signature(:zio, :print_char), do: {[:i32], []}
  defp get_signature(:zio, :read_char), do: {[], [:i32]}
  defp get_signature(:zio, :get_random_seed), do: {[], [:i32]}
  defp get_signature(:zio, :get_capabilities), do: {[], [:i32]}
  defp get_signature(:zio, :halt), do: {[:i32, :i32, :i32], []}
  defp get_signature(:zio, :log_step), do: {[:i32, :i32], []}
  defp get_signature(:zio, :tokenize), do: {[:i32, :i32, :i32, :i32], []}

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
