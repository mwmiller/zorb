defmodule Zorb.Runner do
  @moduledoc false

  def run(path, owner \\ nil, opts \\ []) do
    owner = owner || self()
    story = File.read!(path)

    # Get Extension Table address from Header word 0x34
    if story == nil, do: raise("No story provided")

    # Agent state: %{instance: nil, buffer: [], halt: nil, owner: owner}
    {:ok, agent} =
      Agent.start_link(fn -> %{instance: nil, buffer: [], halt: nil, owner: owner} end)

    base_imports = build_imports(agent)
    overrides = Keyword.get(opts, :imports, %{})

    # Merge overrides into zio namespace
    merged_zio = Map.merge(base_imports["zio"], Map.get(overrides, "zio", %{}))
    imports = Map.put(base_imports, "zio", merged_zio)

    wasm_bytes = Zorb.Capsule.compile(path)
    {:ok, instance} = Wasmex.start_link(%{bytes: wasm_bytes, imports: imports})
    Agent.update(agent, fn s -> %{s | instance: instance} end)

    {:ok, memory} = Wasmex.memory(instance)
    {:ok, store} = Wasmex.store(instance)
    Wasmex.Memory.write_binary(store, memory, 0, story)

    # Call load_story to set @story_len and fill memory
    {:ok, _} = Wasmex.call_function(instance, "load_story", [0, byte_size(story)])

    # Init with stack at 0xA0000 (safely above 512KB story limit)
    {:ok, _} = Wasmex.call_function(instance, "init", [0xA0000])

    # Load default Unicode table at 0x80000
    default_unicode = Zorb.Interpreter.unicode_table()
    binary_table = for char <- default_unicode, into: <<>>, do: <<char::integer-size(16)>>
    Wasmex.Memory.write_binary(store, memory, 0x80000, binary_table)

    # Run the loop in a separate task so this process can receive input messages
    task = Task.async(fn -> loop(instance, agent, 0) end)

    message_loop(task, agent)
  end

  defp message_loop(task, agent) do
    receive do
      msg ->
        case msg do
          {:zorb_input, char} ->
            char =
              case char do
                <<c::8, _::binary>> -> c
                c when is_integer(c) -> c
              end

            Agent.update(agent, fn s ->
              %{s | buffer: s.buffer ++ [char]}
            end)

            send(task.pid, {:zorb_input_ready})
            message_loop(task, agent)

          {^task, res} ->
            res

          {:DOWN, _ref, :process, _pid, _reason} ->
            :ok

          _ ->
            message_loop(task, agent)
        end
    end
  end

  def inject_input(pid, chars) when is_list(chars) do
    for char <- chars do
      send(pid, {:zorb_input, char})
    end
  end

  defp build_imports(agent) do
    zio = %{
      "print_char" => {:fn, [:i32], [], print_char_impl(agent)},
      "read_char" => {:fn, [], [:i32], read_char_impl(agent)},
      "get_random_seed" => {:fn, [], [:i32], get_random_seed_impl()},
      "get_capabilities" => {:fn, [], [:i32], get_capabilities_impl()},
      "halt" => {:fn, [:i32, :i32, :i32], [], halt_impl(agent)},
      "tokenize" => {:fn, [:i32, :i32, :i32, :i32], [], &Zorb.Tokeniser.tokenize/5},
      "log_step" => {:fn, [:i32, :i32], [], fn _ctx, _pc, _b -> nil end}
    }

    %{
      "zio" => zio,
      "Zorb.Capsule.Host" => zio,
      "Elixir.Zorb.Capsule.Host" => zio
    }
  end

  defp print_char_impl(agent) do
    fn _ctx, char ->
      owner = Agent.get(agent, fn s -> s.owner end)
      send(owner, {:zorb_output, char})
      nil
    end
  end

  defp read_char_impl(agent) do
    fn _ctx ->
      wait_for_input(agent)
    end
  end

  defp wait_for_input(agent) do
    case Agent.get(agent, fn s -> s.buffer end) do
      [char | rest] ->
        Agent.update(agent, fn s -> %{s | buffer: rest} end)

        zscii = if char == 10, do: 13, else: char

        zscii

      [] ->
        receive do
          {:zorb_input_ready} ->
            wait_for_input(agent)
        after
          1000 ->
            wait_for_input(agent)
        end
    end
  end

  defp get_random_seed_impl do
    fn _ctx -> :rand.uniform(0x7FFFFFFF) end
  end

  defp get_capabilities_impl do
    # Bit 3: Font 3 (character graphics) available
    fn _ctx -> 0x08 end
  end

  defp halt_impl(agent) do
    fn _ctx, reason, pc, opcode ->
      owner = Agent.get(agent, fn s -> s.owner end)
      send(owner, {:zorb_halt, reason, pc, opcode})
      Agent.update(agent, fn s -> %{s | halt: {reason, pc, opcode}} end)
      nil
    end
  end

  # Safety limit of 10 million steps
  @max_steps 10_000_000

  defp loop(instance, agent, steps) when steps < @max_steps do
    case Agent.get(agent, fn s -> s.halt end) do
      nil ->
        case Wasmex.call_function(instance, "run_steps", [1000], 60_000) do
          {:ok, _} -> loop(instance, agent, steps + 1000)
          {:error, reason} -> {:error, reason}
        end

      halt ->
        handle_halt(halt)
    end
  end

  defp loop(_instance, _agent, _steps), do: :ok

  defp handle_halt({0, _pc, _}) do
    # Normal halt
    :ok
  end

  defp handle_halt({1, pc, _}) do
    IO.puts("Halt: Stack overflow at PC #{pc}")
    :error
  end

  defp handle_halt({2, pc, _}) do
    IO.puts("Halt: Stack underflow at PC #{pc}")
    :error
  end

  defp handle_halt({3, pc, opcode}) do
    IO.puts("Halt: Illegal opcode #{opcode} at PC #{pc}")
    :error
  end

  defp handle_halt({4, pc, _}) do
    IO.puts("Halt: Static memory write at PC #{pc}")
    :error
  end

  defp handle_halt({code, pc, extra}) do
    IO.puts("Halt: Unknown code #{code} at PC #{pc} (extra: #{extra})")
    :error
  end
end
