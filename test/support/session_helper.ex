defmodule Zorb.TestSupport.SessionHelper do
  @moduledoc """
  Helper to run stories using Zorb.Session for testing purposes.
  Replaces the legacy Zorb.Runner.
  """

  def run(path, owner \\ nil, opts \\ []) do
    owner = owner || self()
    {:ok, session_pid} = Zorb.Session.start_link(path, Keyword.put(opts, :notify_to, self()))

    # Bridge messages from Session to owner
    message_loop(session_pid, owner)
  end

  defp message_loop(session_pid, owner) do
    receive do
      {:zorb_output, output} ->
        send(owner, {:zorb_output, output})
        message_loop(session_pid, owner)

      {:zorb_halt, reason, pc, opcode} ->
        send(owner, {:zorb_halt, reason, pc, opcode})
        :ok

      {:zorb_input, char} ->
        Zorb.Session.send_input(session_pid, char)
        message_loop(session_pid, owner)

      msg ->
        # Pass-through other messages
        send(owner, msg)
        message_loop(session_pid, owner)
    end
  end
end
