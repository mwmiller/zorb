defmodule Zorb.Session do
  @moduledoc """
  A GenServer-based capsule host for interactive Z-machine sessions.

  This module provides a non-blocking, OTP-compliant way to run Z-machine stories.
  It communicates with a listener process via messages.
  """

  use GenServer
  require Logger
  import Bitwise

  defmodule State do
    @moduledoc false
    defstruct [
      :instance,
      :mem,
      :store,
      :input_buffer,
      :waiting_input,
      :notify_to,
      :halted,
      :last_char,
      :current_window,
      :task,
      :timeout,
      :saved_state,
      :undo_stack,
      :last_undone
    ]
  end

  # --- Client API ---

  @doc """
  Starts a new Z-machine session.

  The first argument can be:
  - `{:story_path, path}`: Compile the story at the given path.
  - `{:wasm_bytes, bytes}`: Use the provided WASM bytes directly.

  Options:
  - :notify_to: The PID to send output and halt messages to. Defaults to self().
  - :timeout: Timeout for WASM execution steps. Defaults to :infinity.
  - :imports: Map of WASM import overrides.
  - :cache: Boolean, whether to cache compilation (only if {:story_path, path} is used).
  """
  def start_link(source, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, :infinity)
    start_timeout = if timeout == :infinity, do: :infinity, else: timeout + 5000
    GenServer.start_link(__MODULE__, {source, opts}, timeout: start_timeout)
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

  @doc false
  @impl true
  def init({source, opts}) do
    notify_to = Keyword.get(opts, :notify_to, self())
    timeout = Keyword.get(opts, :timeout, :infinity)

    wasm_bytes = resolve_wasm_bytes(source, opts)

    session_pid = self()
    imports = build_all_imports(session_pid, opts)

    case Wasmex.start_link(%{bytes: wasm_bytes, imports: imports}) do
      {:ok, instance} ->
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
    with {:ok, _} <- Wasmex.call_function(instance, "init", [], timeout),
         {:ok, mem} <- Wasmex.memory(instance),
         {:ok, store} <- Wasmex.store(instance) do
      state = %State{
        instance: instance,
        mem: mem,
        store: store,
        input_buffer: [],
        waiting_input: nil,
        notify_to: notify_to,
        halted: false,
        last_char: nil,
        current_window: 0,
        timeout: timeout,
        undo_stack: [],
        last_undone: nil
      }

      # Start the WASM loop in a separate Task
      session_pid = self()

      task =
        Task.async(fn ->
          run_loop(instance, session_pid, timeout)
        end)

      {:ok, %{state | task: task}}
    else
      {:error, reason} ->
        Logger.error("Zorb Session: WASM init failed: #{inspect(reason)}")
        {:stop, reason}

      _ ->
        Logger.error("Zorb Session: Failed to get memory or store")
        {:stop, :missing_memory}
    end
  end

  @doc false
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

  @doc false
  @impl true
  def handle_call({:save, pc, sp, fp, csp, rs}, _from, state) do
    mem = state.mem
    store = state.store

    # Read dynamic memory size from header (offset 0x0E)
    header_bytes = Wasmex.Memory.read_binary(store, mem, 0x0E, 2)
    <<static_base::16>> = header_bytes

    # Dynamic memory: [0, static_base)
    dynamic_mem = Wasmex.Memory.read_binary(store, mem, 0, static_base)

    # Z-stack: [0x90000, sp)
    # sp is the number of words from the base (0x90000)
    # Each word is 2 bytes.
    stack = Wasmex.Memory.read_binary(store, mem, 0x90000, sp * 2)

    # Call stack: [0x98000, csp)
    # csp is the number of words from the base (0x98000)
    call_stack = Wasmex.Memory.read_binary(store, mem, 0x98000, csp * 2)

    saved_state = %{
      dynamic_mem: dynamic_mem,
      stack: stack,
      call_stack: call_stack,
      pc: pc,
      sp: sp,
      fp: fp,
      csp: csp,
      rs: rs
    }

    {:reply, 1, %{state | saved_state: saved_state}}
  end

  @doc false
  @impl true
  def handle_call(:restore, _from, state) do
    case state.saved_state do
      nil ->
        {:reply, 0, state}

      saved ->
        mem = state.mem
        store = state.store

        Wasmex.Memory.write_binary(store, mem, 0, saved.dynamic_mem)
        Wasmex.Memory.write_binary(store, mem, 0x90000, saved.stack)
        Wasmex.Memory.write_binary(store, mem, 0x98000, saved.call_stack)
        {:reply, 1, state}
    end
  end

  @doc false
  @impl true
  def handle_call({:get_restored, type}, _from, state) do
    case state.saved_state do
      nil ->
        {:reply, 0, state}

      saved ->
        val =
          case type do
            :pc -> saved.pc
            :sp -> saved.sp
            :fp -> saved.fp
            :csp -> saved.csp
            :rs -> saved.rs
          end

        {:reply, val, state}
    end
  end

  @doc false
  @impl true
  def handle_call({:save_undo, pc, sp, fp, csp, rs}, _from, state) do
    mem = state.mem
    store = state.store

    header_bytes = Wasmex.Memory.read_binary(store, mem, 0x0E, 2)
    <<static_base::16>> = header_bytes

    dynamic_mem = Wasmex.Memory.read_binary(store, mem, 0, static_base)
    stack = Wasmex.Memory.read_binary(store, mem, 0x90000, sp * 2)
    call_stack = Wasmex.Memory.read_binary(store, mem, 0x98000, csp * 2)

    new_undo = %{
      dynamic_mem: dynamic_mem,
      stack: stack,
      call_stack: call_stack,
      pc: pc,
      sp: sp,
      fp: fp,
      csp: csp,
      rs: rs
    }

    # Keep only the last 16 undo levels
    new_stack = [new_undo | state.undo_stack] |> Enum.take(16)

    {:reply, 1, %{state | undo_stack: new_stack}}
  end

  @doc false
  @impl true
  def handle_call(:restore_undo, _from, state) do
    case state.undo_stack do
      [] ->
        {:reply, 0, state}

      [undone | rest] ->
        mem = state.mem
        store = state.store

        Wasmex.Memory.write_binary(store, mem, 0, undone.dynamic_mem)
        Wasmex.Memory.write_binary(store, mem, 0x90000, undone.stack)
        Wasmex.Memory.write_binary(store, mem, 0x98000, undone.call_stack)

        # We keep the restored state in a temporary field so getters can access it
        # Actually, let's just use the restored state directly.
        # But we need a way to return the values to the WASM.
        # We can store the "last undone" state in the GenServer state.
        {:reply, 1, %{state | undo_stack: rest, last_undone: undone}}
    end
  end

  @doc false
  @impl true
  def handle_call({:get_undone, type}, _from, state) do
    case state.last_undone do
      nil ->
        {:reply, 0, state}

      undone ->
        val =
          case type do
            :pc -> undone.pc
            :sp -> undone.sp
            :fp -> undone.fp
            :csp -> undone.csp
            :rs -> undone.rs
          end

        {:reply, val, state}
    end
  end

  @doc false
  @impl true
  def handle_cast({:set_window, window_id}, state) do
    {:noreply, %{state | current_window: window_id}}
  end

  @doc false
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

  @doc false
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

  @doc false
  @impl true
  def handle_info({:zorb_halt, reason, pc, opcode}, state) do
    send(state.notify_to, {:zorb_halt, reason, pc, opcode})
    {:stop, :normal, %{state | halted: true}}
  end

  @doc false
  @impl true
  def handle_info({ref, :ok}, state) do
    case state.task do
      %{ref: ^ref} -> {:noreply, state}
      _ -> {:noreply, state}
    end
  end

  @doc false
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

  @doc false
  @impl true
  def terminate(_reason, state) do
    if state.task do
      Task.shutdown(state.task, :brutal_kill)
    end

    :ok
  end

  # --- Internal functions ---

  defp run_loop(instance, session_pid, timeout) do
    case Wasmex.call_function(instance, "run_steps", [1000], timeout) do
      {:ok, [0]} ->
        run_loop(instance, session_pid, timeout)

      {:ok, [1]} ->
        :ok

      {:error, reason} ->
        case reason do
          "Function execution timed out" ->
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
             try do
               GenServer.call(session_pid, :get_input, :infinity)
             catch
               :exit, _ -> 0
             end
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
        "get_capabilities" => {:fn, [], [:i32], fn _ctx -> 0x1F end},
        "halt" =>
          {:fn, [:i32, :i32, :i32], [],
           fn _ctx, reason, pc, opcode ->
             send(session_pid, {:zorb_halt, reason, pc, opcode})
             nil
           end},
        "log_zchar" =>
          {:fn, [:i32, :i32, :i32], [],
           fn _ctx, _alph, _zchar, _zscii ->
             nil
           end},
        "set_window" =>
          {:fn, [:i32], [],
           fn _ctx, window_id ->
             GenServer.cast(session_pid, {:set_window, window_id})
             send(session_pid, {:zorb_output, {:set_window, window_id}})
             nil
           end},
        "split_window" =>
          {:fn, [:i32], [],
           fn _ctx, lines ->
             send(session_pid, {:zorb_output, {:split_window, lines}})
             nil
           end},
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
        "set_colour" =>
          {:fn, [:i32, :i32], [],
           fn _ctx, fg, bg ->
             send(session_pid, {:zorb_output, {:colour, fg, bg}})
             nil
           end},
        "sound_effect" =>
          {:fn, [:i32], [],
           fn _ctx, number ->
             send(session_pid, {:zorb_output, {:sound, number}})
             nil
           end},
        "get_screen_size" =>
          {:fn, [], [:i32],
           fn _ctx ->
             24 <<< 16 ||| 80
           end},
        "save" =>
          {:fn, [:i32, :i32, :i32, :i32, :i32], [:i32],
           fn _ctx, pc, sp, fp, csp, rs ->
             GenServer.call(session_pid, {:save, pc, sp, fp, csp, rs}, :infinity)
           end},
        "restore" =>
          {:fn, [], [:i32],
           fn _ctx ->
             GenServer.call(session_pid, :restore, :infinity)
           end},
        "get_restored_pc" =>
          {:fn, [], [:i32], fn _ctx -> GenServer.call(session_pid, {:get_restored, :pc}) end},
        "get_restored_sp" =>
          {:fn, [], [:i32], fn _ctx -> GenServer.call(session_pid, {:get_restored, :sp}) end},
        "get_restored_fp" =>
          {:fn, [], [:i32], fn _ctx -> GenServer.call(session_pid, {:get_restored, :fp}) end},
        "get_restored_csp" =>
          {:fn, [], [:i32], fn _ctx -> GenServer.call(session_pid, {:get_restored, :csp}) end},
        "get_restored_random_state" =>
          {:fn, [], [:i32], fn _ctx -> GenServer.call(session_pid, {:get_restored, :rs}) end},
        "save_undo" =>
          {:fn, [:i32, :i32, :i32, :i32, :i32], [:i32],
           fn _ctx, pc, sp, fp, csp, rs ->
             GenServer.call(session_pid, {:save_undo, pc, sp, fp, csp, rs}, :infinity)
           end},
        "restore_undo" =>
          {:fn, [], [:i32],
           fn _ctx ->
             GenServer.call(session_pid, :restore_undo, :infinity)
           end},
        "get_undone_pc" =>
          {:fn, [], [:i32], fn _ctx -> GenServer.call(session_pid, {:get_undone, :pc}) end},
        "get_undone_sp" =>
          {:fn, [], [:i32], fn _ctx -> GenServer.call(session_pid, {:get_undone, :sp}) end},
        "get_undone_fp" =>
          {:fn, [], [:i32], fn _ctx -> GenServer.call(session_pid, {:get_undone, :fp}) end},
        "get_undone_csp" =>
          {:fn, [], [:i32], fn _ctx -> GenServer.call(session_pid, {:get_undone, :csp}) end},
        "get_undone_random_state" =>
          {:fn, [], [:i32], fn _ctx -> GenServer.call(session_pid, {:get_undone, :rs}) end}
      }
    }
  end
end
