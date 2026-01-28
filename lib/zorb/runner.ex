defmodule Zorb.Runner do
  @moduledoc false
  alias Zorb.Interpreter

  def run(path, owner \\ nil) do
    owner = owner || self()
    story = File.read!(path)

    # Agent state: %{instance: nil, buffer: [], halt: nil, owner: owner}
    {:ok, agent} =
      Agent.start_link(fn -> %{instance: nil, buffer: [], halt: nil, owner: owner} end)

    imports = build_imports(agent)

    wat = Orb.to_wat(Interpreter)
    {:ok, instance} = Wasmex.start_link(%{bytes: wat, imports: imports})
    Agent.update(agent, fn s -> %{s | instance: instance} end)

    {:ok, memory} = Wasmex.memory(instance)
    {:ok, store} = Wasmex.store(instance)
    Wasmex.Memory.write_binary(store, memory, 0, story)

    # Call load_story to set @story_len and fill memory
    {:ok, _} = Wasmex.call_function(instance, "load_story", [0, byte_size(story)])

    # Init with stack at 0xC0000
    {:ok, _} = Wasmex.call_function(instance, "init", [0xC0000])

    # Run the loop in a separate task so this process can receive input messages
    task = Task.async(fn -> loop(instance, agent, 0) end)

    message_loop(task, agent)
  end

  defp message_loop(task, agent) do
    receive do
      {:zorb_input, char} ->
        Agent.update(agent, fn s -> %{s | buffer: s.buffer ++ [char]} end)

        # Notify the task if it's waiting for input
        case Task.yield(task, 0) do
          nil -> send(task.pid, {:zorb_input_ready})
          _ -> :ok
        end

        message_loop(task, agent)

      # Handle Task completion
      {^task, res} ->
        res

      # Handle Task down
      {:DOWN, _ref, :process, _pid, _reason} ->
        :ok
    end
  end

  def inject_input(pid, chars) when is_list(chars) do
    for char <- chars do
      send(pid, {:zorb_input, char})
    end
  end

  defp build_imports(agent) do
    %{
      "zio" => %{
        "print_char" => {:fn, [:i32], [], print_char_impl(agent)},
        "read_char" => {:fn, [], [:i32], read_char_impl(agent)},
        "get_random_seed" => {:fn, [], [:i32], get_random_seed_impl()},
        "get_capabilities" => {:fn, [], [:i32], get_capabilities_impl()},
        "halt" => {:fn, [:i32, :i32, :i32], [], halt_impl(agent)},
        "log_step" =>
          {:fn, [:i32, :i32], [],
           fn _ctx, code, val ->
             IO.puts("DEBUG: code=#{code} val=#{val}")
             nil
           end}
      }
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
    # Check if we already have input
    case Agent.get(agent, fn s -> s.buffer end) do
      [char | rest] ->
        Agent.update(agent, fn s -> %{s | buffer: rest} end)
        char

      [] ->
        # Wait for a message from message_loop
        receive do
          {:zorb_input_ready} -> wait_for_input(agent)
        after
          1000 -> wait_for_input(agent)
        end
    end
  end

  defp get_random_seed_impl do
    fn _ctx -> :rand.uniform(0x7FFFFFFF) end
  end

  defp get_capabilities_impl do
    fn _ctx -> 0 end
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
        case Wasmex.call_function(instance, "run_steps", [100], 30_000) do
          {:ok, _} -> loop(instance, agent, steps + 100)
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

  defp handle_halt({code, pc, extra}) do
    IO.puts("Halt: Unknown code #{code} at PC #{pc} (extra: #{extra})")
    :error
  end
end
