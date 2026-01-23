defmodule Zorb.Runner do
  alias Zorb.Interpreter

  def run(path) do
    story = File.read!(path)

    # Agent state: %{instance: nil, buffer: []}
    {:ok, agent} = Agent.start_link(fn -> %{instance: nil, buffer: []} end)

    imports = %{
      "zio" => %{
        "print_char" =>
          {:fn, [:i32], [],
           fn _ctx, [char] ->
             try do
               IO.write([char])
             rescue
               _ -> IO.write("?")
             end

             nil
           end},
        "read_char" =>
          {:fn, [], [:i32],
           fn _ctx ->
             buffer = Agent.get(agent, fn s -> s.buffer end)

             case buffer do
               [char | rest] ->
                 Agent.update(agent, fn s -> %{s | buffer: rest} end)
                 char

               [] ->
                 input = IO.gets("")

                 case input do
                   :eof ->
                     13

                   line ->
                     chars = String.to_charlist(line)
                     [char | rest] = chars
                     Agent.update(agent, fn s -> %{s | buffer: rest} end)
                     char
                 end
             end
           end},
        "halt" =>
          {:fn, [:i32], [],
           fn _ctx, [reason] ->
             IO.puts("\nSystem Halted: #{reason}")
             # Throwing here will cause call_function to return {:error, ...}
             throw(:halt)
           end}
      }
    }

    wat = Orb.to_wat(Interpreter)
    {:ok, instance} = Wasmex.start_link(%{bytes: wat, imports: imports})
    Agent.update(agent, fn s -> %{s | instance: instance} end)

    {:ok, memory} = Wasmex.memory(instance)
    {:ok, store} = Wasmex.store(instance)
    Wasmex.Memory.write_binary(store, memory, 0, story)

    # Init with stack at 0xC0000
    {:ok, _} = Wasmex.call_function(instance, "init", [0xC0000, byte_size(story)])

    loop(instance)
  end

  defp loop(instance) do
    case Wasmex.call_function(instance, "step", []) do
      {:ok, _} -> loop(instance)
      {:error, _reason} -> :ok
    end
  end
end
