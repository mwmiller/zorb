defmodule Zorb.Runner do
  @moduledoc false

  def run(path, owner \\ nil, opts \\ []) do
    owner = owner || self()
    story = File.read!(path)
    timeout = Keyword.get(opts, :timeout, :infinity)

    # Get Extension Table address from Header word 0x34
    if story == nil, do: raise("No story provided")

    # Agent state: %{instance: nil, buffer: [], halt: nil, owner: owner, last_char: nil, timeout: timeout}
    {:ok, agent} =
      Agent.start_link(fn ->
        %{instance: nil, buffer: [], halt: nil, owner: owner, last_char: nil, timeout: timeout}
      end)

    base_imports = build_imports(agent)
    overrides = Keyword.get(opts, :imports, %{})

    # Merge overrides into zio namespace
    merged_zio = Map.merge(base_imports["zio"], Map.get(overrides, "zio", %{}))
    imports = Map.put(base_imports, "zio", merged_zio)

    require Logger
    Logger.debug("Zorb: Loading story #{Path.basename(path)}...")
    wasm_bytes = Zorb.Capsule.compile(path)
    {:ok, instance} = Wasmex.start_link(%{bytes: wasm_bytes, imports: imports})
    Agent.update(agent, fn s -> %{s | instance: instance} end)

    # Init
    Logger.debug("Zorb: Calling WASM init...")
    {:ok, _} = Wasmex.call_function(instance, "init", [])

    # Run the loop in a separate task so this process can receive input messages
    Logger.debug("Zorb: Starting loop task...")
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
      "print_num" => {:fn, [:i32], [], print_num_impl(agent)},
      "read_char" => {:fn, [], [:i32], read_char_impl(agent)},
      "get_random" => {:fn, [:i32], [:i32], get_random_impl(agent)},
      "get_random_seed" => {:fn, [], [:i32], get_random_seed_impl()},
      "get_capabilities" => {:fn, [], [:i32], get_capabilities_impl()},
      "halt" => {:fn, [:i32, :i32, :i32], [], halt_impl(agent)},
      "tokenize" => {:fn, [:i32, :i32, :i32, :i32], [], fn _ctx, _t, _p, _d, _f -> nil end},
      "log_step" => {:fn, [:i32, :i32, :i32], [], log_step_impl(agent)}
    }

    %{
      "zio" => zio
    }
  end

  defp log_step_impl(_agent) do
    fn _ctx, tick, pc, opcode ->
      # owner = Agent.get(agent, fn s -> s.owner end)
      # send(owner, {:zorb_step, tick, pc, opcode})
      # IO.puts(:stderr, "Step #{tick}: PC=0x#{Integer.to_string(pc, 16)} Op=0x#{Integer.to_string(opcode, 16)}")
      _ = tick
      _ = pc
      _ = opcode
      nil
    end
  end

  defp print_char_impl(agent) do
    fn _ctx, char ->
      Agent.update(agent, fn s -> %{s | last_char: char} end)
      owner = Agent.get(agent, fn s -> s.owner end)
      send(owner, {:zorb_output, char})
      nil
    end
  end

  defp print_num_impl(agent) do
    fn _ctx, num ->
      str = Integer.to_string(num)
      owner = Agent.get(agent, fn s -> s.owner end)

      for <<c::8 <- str>> do
        send(owner, {:zorb_output, c})
      end

      nil
    end
  end

  defp get_random_impl(_agent) do
    fn _ctx, max ->
      if max > 0 do
        :rand.uniform(max)
      else
        0
      end
    end
  end

  defp read_char_impl(agent) do
    fn ctx ->
      # Ergonomics: Add a space after the prompt (>) if not present.
      # This happens at the Host level so it only triggers once per logical input request.
      if Agent.get(agent, fn s -> s.last_char end) == ?> do
        print_char_impl(agent).(ctx, 32)
      end

      wait_for_input(agent)
    end
  end

  defp wait_for_input(agent) do
    case Agent.get(agent, fn s -> s.buffer end) do
      [char | rest] ->
        Agent.update(agent, fn s -> %{s | buffer: rest} end)

        zscii = if char == 10, do: 13, else: char
        require Logger
        Logger.debug("Zorb: wait_for_input returning ZSCII #{zscii} ('#{<<zscii>>}')")

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
        timeout = Agent.get(agent, fn s -> s.timeout end)

        case Wasmex.call_function(instance, "run_steps", [1000], timeout) do
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

  defp handle_halt({4, pc, addr}) do
    IO.puts("Halt: Static memory write at PC #{pc} (addr: #{addr})")
    :error
  end

  defp handle_halt({code, pc, extra}) do
    IO.puts("Halt: Unknown code #{code} at PC #{pc} (extra: #{extra})")
    :error
  end
end
