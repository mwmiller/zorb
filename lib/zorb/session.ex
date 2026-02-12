defmodule Zorb.Session do
  @moduledoc """
  A GenServer-based capsule host for interactive Z-machine sessions.

  This module provides a non-blocking, OTP-compliant way to run Z-machine stories.
  It communicates with a listener process via messages.
  """

  use GenServer
  require Logger

  defmodule State do
    @moduledoc false
    defstruct [
      :instance,
      :input_buffer,
      :waiting_input,
      :notify_to,
      :halted,
      :last_char,
      :current_window,
      :task,
      :timeout
    ]
  end

  # --- Client API ---

  @doc """
  Starts a new Z-machine session.

  The first argument can be:
  - `{:story_path, path}`: Compile the story at the given path.
  - `{:wasm_bytes, bytes}`: Use the provided WASM bytes directly.

  Options:
  - `:notify_to`: The PID to send output and halt messages to. Defaults to `self()`.
  - `:timeout`: Timeout for WASM execution steps. Defaults to `:infinity`.
  - `:imports`: Map of WASM import overrides.
  - `:cache`: Boolean, whether to cache compilation (only if `{:story_path, path}` is used).
  """
  def start_link(source, opts \\ []) do
    GenServer.start_link(__MODULE__, {source, opts})
  end

  @doc """
  Sends input characters or a string to the session.
  """
  def send_input(pid, input) when is_binary(input) do
    for <<char::8 <- input>>, do: send(pid, {:zorb_input, char})
    :ok
  end

  def send_input(pid, char) when is_integer(char) do
    send(pid, {:zorb_input, char})
    :ok
  end

  # --- GenServer Callbacks ---

  @impl true
  def init({source, opts}) do
    notify_to = Keyword.get(opts, :notify_to, self())
    timeout = Keyword.get(opts, :timeout, :infinity)

    Logger.debug("Zorb Session: Resolving WASM bytes...")
    wasm_bytes = resolve_wasm_bytes(source, opts)
    Logger.debug("Zorb Session: WASM bytes resolved (#{byte_size(wasm_bytes)} bytes)")

    session_pid = self()
    imports = build_all_imports(session_pid, opts)

    Logger.debug("Zorb Session: Starting WASM instance...")

    case Wasmex.start_link(%{bytes: wasm_bytes, imports: imports}) do
      {:ok, instance} ->
        Logger.debug("Zorb Session: WASM instance started, initializing...")
        initialize_instance(instance, notify_to, timeout)

      {:error, reason} ->
        Logger.error("Zorb Session: Failed to start WASM instance: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  defp resolve_wasm_bytes({:wasm_bytes, bytes}, _opts), do: bytes

  defp resolve_wasm_bytes({:story_path, path}, opts) do
    Zorb.Capsule.compile(path, cache: Keyword.get(opts, :cache, false))
  end

  defp resolve_wasm_bytes(path, opts) when is_binary(path) do
    Zorb.Capsule.compile(path, cache: Keyword.get(opts, :cache, false))
  end

  defp build_all_imports(session_pid, opts) do
    base_imports = build_imports(session_pid)
    overrides = Keyword.get(opts, :imports, %{})

    merged_zio =
      case Map.get(overrides, "zio") do
        nil -> Map.get(base_imports, "zio")
        over -> Map.merge(Map.get(base_imports, "zio"), over)
      end

    Map.put(base_imports, "zio", merged_zio)
  end

  defp initialize_instance(instance, notify_to, timeout) do
    Logger.debug("Zorb Session: Calling WASM init...")

    case Wasmex.call_function(instance, "init", []) do
      {:ok, _} ->
        Logger.debug("Zorb Session: WASM init successful")

        state = %State{
          instance: instance,
          input_buffer: [],
          waiting_input: nil,
          notify_to: notify_to,
          halted: false,
          last_char: nil,
          current_window: 0,
          timeout: timeout
        }

        # Start the WASM loop in a separate Task
        session_pid = self()

        task =
          Task.async(fn ->
            Logger.debug("Zorb Session: Starting run_loop task...")
            run_loop(instance, session_pid, timeout)
          end)

        {:ok, %{state | task: task}}

      {:error, reason} ->
        Logger.error("Zorb Session: WASM init failed: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl true
  def handle_call(:get_input, from, state) do
    # Ergonomics: Add space after prompt
    case state.last_char do
      ?> -> send(state.notify_to, {:zorb_output, 32})
      _ -> :ok
    end

    case state.input_buffer do
      [char | rest] ->
        {:reply, char, %{state | input_buffer: rest}}

      [] ->
        {:noreply, %{state | waiting_input: from}}
    end
  end

  @impl true
  def handle_cast({:set_window, window_id}, state) do
    {:noreply, %{state | current_window: window_id}}
  end

  @impl true
  def handle_info({:zorb_input, char}, state) do
    zscii =
      case char do
        10 -> 13
        c -> c
      end

    case state.waiting_input do
      nil ->
        {:noreply, %{state | input_buffer: state.input_buffer ++ [zscii]}}

      from ->
        GenServer.reply(from, zscii)
        {:noreply, %{state | waiting_input: nil}}
    end
  end

  @impl true
  def handle_info({:zorb_output, output}, state) do
    send(state.notify_to, {:zorb_output, output})

    new_state =
      case output do
        char when is_integer(char) -> %{state | last_char: char}
        _ -> state
      end

    {:noreply, new_state}
  end

  @impl true
  def handle_info({:zorb_halt, reason, pc, opcode}, state) do
    Logger.debug(
      "Zorb Session: HALTED: reason=#{reason}, PC=0x#{Integer.to_string(pc, 16)}, Op=0x#{Integer.to_string(opcode, 16)}"
    )

    send(state.notify_to, {:zorb_halt, reason, pc, opcode})
    {:stop, :normal, %{state | halted: true}}
  end

  @impl true
  def handle_info({ref, :ok}, state) do
    case state.task do
      %{ref: ^ref} -> {:noreply, state}
      _ -> {:noreply, state}
    end
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, reason}, state) do
    case state.task do
      %{ref: ^ref} ->
        case reason do
          :normal ->
            {:stop, :normal, state}

          _ ->
            Logger.error("Zorb Session: Loop task died: #{inspect(reason)}")
            {:stop, reason, state}
        end

      _ ->
        {:noreply, state}
    end
  end

  # --- Internal functions ---

  defp run_loop(instance, session_pid, timeout) do
    case Wasmex.call_function(instance, "run_steps", [1000], timeout) do
      {:ok, [0]} ->
        Logger.debug("Zorb Session: 1000 steps executed")
        run_loop(instance, session_pid, timeout)

      {:ok, [1]} ->
        Logger.debug("Zorb Session: run_steps reported halt, stopping task.")
        :ok

      {:error, reason} ->
        case reason do
          "Function execution timed out" ->
            Logger.debug("Zorb Session: run_steps timed out, resuming...")
            run_loop(instance, session_pid, timeout)

          _ ->
            Logger.error("Zorb Session: WASM execution error: #{inspect(reason)}")
            # Signal illegal opcode/error
            send(session_pid, {:zorb_halt, 3, 0, 0})
            :error
        end
    end
  end

  defp build_imports(session_pid) do
    %{
      "zio" => %{
        "print_char" =>
          {:fn, [:i32], [],
           fn _ctx, char ->
             Logger.debug("Zorb Session: print_char(#{char})")
             send(session_pid, {:zorb_output, char})
             nil
           end},
        "print_num" =>
          {:fn, [:i32], [],
           fn _ctx, num ->
             for <<c::8 <- Integer.to_string(num)>>, do: send(session_pid, {:zorb_output, c})
             nil
           end},
        "read_char" =>
          {:fn, [], [:i32],
           fn _ctx ->
             Logger.debug("Zorb Session: read_char() called")
             GenServer.call(session_pid, :get_input, :infinity)
           end},
        "get_random" =>
          {:fn, [:i32], [:i32],
           fn _ctx, max ->
             case max > 0 do
               true -> :rand.uniform(max)
               false -> 0
             end
           end},
        "get_random_seed" => {:fn, [], [:i32], fn _ctx -> :rand.uniform(0x7FFFFFFF) end},
        "get_capabilities" => {:fn, [], [:i32], fn _ctx -> 0x0F end},
        "halt" =>
          {:fn, [:i32, :i32, :i32], [],
           fn _ctx, reason, pc, opcode ->
             send(session_pid, {:zorb_halt, reason, pc, opcode})
             nil
           end},
        "log_zchar" =>
          {:fn, [:i32, :i32, :i32], [],
           fn _ctx, alph, zchar, zscii ->
             Logger.debug(
               "Zorb Session: decode_zchar: alph=#{alph}, zchar=#{zchar}, zscii=#{zscii} ('#{[zscii]}')"
             )

             nil
           end},
        "log_step" =>
          {:fn, [:i32, :i32, :i32], [],
           fn _ctx, tick, pc, opcode ->
             if tick <= 5 or rem(tick, 1000) == 0 do
               Logger.debug(
                 "Zorb Session: Step #{tick}: PC=0x#{Integer.to_string(pc, 16)} Op=0x#{Integer.to_string(opcode, 16)}"
               )
             end

             nil
           end},
        "set_window" =>
          {:fn, [:i32], [],
           fn _ctx, window_id ->
             GenServer.cast(session_pid, {:set_window, window_id})
             nil
           end},
        "split_window" => {:fn, [:i32], [], fn _ctx, _lines -> nil end},
        "set_cursor" =>
          {:fn, [:i32, :i32], [],
           fn _ctx, l, c ->
             send(session_pid, {:zorb_output, {:cursor, l, c}})
             nil
           end},
        "erase_window" =>
          {:fn, [:i32], [],
           fn _ctx, id ->
             send(session_pid, {:zorb_output, {:erase_window, id}})
             nil
           end},
        "erase_line" =>
          {:fn, [:i32], [],
           fn _ctx, val ->
             send(session_pid, {:zorb_output, {:erase_line, val}})
             nil
           end},
        "set_text_style" =>
          {:fn, [:i32], [],
           fn _ctx, style ->
             send(session_pid, {:zorb_output, {:style, style}})
             nil
           end},
        "get_screen_size" =>
          {:fn, [], [:i32],
           fn _ctx ->
             import Bitwise
             24 <<< 16 ||| 80
           end}
      }
    }
  end
end
