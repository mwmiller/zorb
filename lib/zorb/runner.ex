defmodule Zorb.Runner do
  alias Zorb.Interpreter

  def run(path) do
    story = File.read!(path)

    # Agent state: %{instance: nil, buffer: []}
    {:ok, agent} = Agent.start_link(fn -> %{instance: nil, buffer: []} end)

    imports = [
      {:zio, :print_char,
       fn char ->
         try do
           IO.write([char])
         rescue
           _ -> IO.write("?")
         end

         0
       end},
      {:zio, :halt,
       fn reason ->
         IO.puts("\nSystem Halted: #{reason}")
         throw(:halt)
         0
       end},
      {:zio, :read_char,
       fn ->
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
       end}
    ]

    instance = OrbWasmtime.Instance.run(Interpreter, imports)
    Agent.update(agent, fn s -> %{s | instance: instance} end)

    OrbWasmtime.Instance.write_memory(instance, 0, :binary.bin_to_list(story))

    # Init with stack at 0xC0000
    OrbWasmtime.Instance.call(instance, :init, 0xC0000, byte_size(story))

    try do
      loop(instance)
    catch
      :halt -> :ok
    end
  end

  defp loop(instance) do
    OrbWasmtime.Instance.call(instance, :step)
    loop(instance)
  end
end
