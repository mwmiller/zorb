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
      :last_undone,
      :pending_interrupt,
      :pending_callers
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

  @doc """
  Triggers a save of the current game state from outside.
  Returns `1` if successful, `0` otherwise.
  """
  def save(pid) do
    GenServer.call(pid, :external_save)
  end

  @doc """
  Restores the previously saved game state from outside.
  Returns `1` if successful, `0` otherwise.
  """
  def restore(pid) do
    GenServer.call(pid, :external_restore)
  end

  @doc """
  Saves the current game state for a future undo from outside.
  Returns `1` if successful, `0` otherwise.
  """
  def save_undo(pid) do
    GenServer.call(pid, :external_save_undo)
  end

  @doc """
  Restores the last undo state from outside.
  Returns `1` if successful, `0` otherwise.
  """
  def restore_undo(pid) do
    GenServer.call(pid, :external_restore_undo)
  end

  @doc """
  Returns the metadata for the running story.
  """
  def metadata(pid) do
    state = :sys.get_state(pid)
    metadata_state(state)
  end

  defp metadata_state(state) do
    version = Wasmex.Memory.read_binary(state.store, state.mem, 0, 1) |> :binary.at(0)
    cmd_prefix = Wasmex.Memory.read_binary(state.store, state.mem, 0x83008, 1) |> :binary.at(0)

    serial = read_string(state, 0x83001, 6)
    chat = read_null_terminated_string(state, 0x83010)
    channel = read_null_terminated_string(state, 0x83050)

    %{
      version: version,
      serial: serial,
      command_prefix: cmd_prefix,
      chat_prefix: chat,
      channel_prefix: channel
    }
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
        last_undone: nil,
        pending_interrupt: 0,
        pending_callers: %{}
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

    if state.pending_interrupt > 0 do
      interrupt = state.pending_interrupt
      code = 0x100 + interrupt
      {:reply, code, %{state | pending_interrupt: 0}}
    else
      case state.input_buffer do
        [char | rest] ->
          {:reply, char, %{state | input_buffer: rest}}

        [] ->
          {:noreply, %{state | waiting_input: from}}
      end
    end
  end

  def handle_call(:check_interrupt, _from, state) do
    interrupt = state.pending_interrupt
    {:reply, interrupt, %{state | pending_interrupt: 0}}
  end

  def handle_call({:save_with_data, data, pc, sp, fp, csp, rs}, _from, state) do
    saved_state = Map.merge(data, %{pc: pc, sp: sp, fp: fp, csp: csp, rs: rs})
    new_state = %{state | saved_state: saved_state}

    case Map.get(new_state.pending_callers, :save) do
      nil ->
        {:reply, 1, new_state}

      caller ->
        GenServer.reply(caller, 1)

        {:reply, 1, %{new_state | pending_callers: Map.delete(new_state.pending_callers, :save)}}
    end
  end

  def handle_call(:external_save, from, state) do
    new_state = %{
      state
      | pending_interrupt: 1,
        pending_callers: Map.put(state.pending_callers, :save, from)
    }

    case state.waiting_input do
      nil ->
        {:noreply, new_state}

      waiter ->
        GenServer.reply(waiter, 0x101)
        {:noreply, %{new_state | waiting_input: nil}}
    end
  end

  def handle_call(:restore_get_data, _from, state) do
    case Map.get(state.pending_callers, :restore) do
      nil ->
        {:reply, state.saved_state, state}

      caller ->
        result = if state.saved_state, do: 1, else: 0
        GenServer.reply(caller, result)

        {:reply, state.saved_state,
         %{state | pending_callers: Map.delete(state.pending_callers, :restore)}}
    end
  end

  def handle_call(:external_restore, from, state) do
    new_state = %{
      state
      | pending_interrupt: 2,
        pending_callers: Map.put(state.pending_callers, :restore, from)
    }

    case state.waiting_input do
      nil ->
        {:noreply, new_state}

      waiter ->
        GenServer.reply(waiter, 0x102)
        {:noreply, %{new_state | waiting_input: nil}}
    end
  end

  def handle_call({:save_undo_with_data, data, pc, sp, fp, csp, rs}, _from, state) do
    new_undo = Map.merge(data, %{pc: pc, sp: sp, fp: fp, csp: csp, rs: rs})
    new_stack = [new_undo | state.undo_stack] |> Enum.take(16)
    new_state = %{state | undo_stack: new_stack}

    case Map.get(new_state.pending_callers, :save_undo) do
      nil ->
        {:reply, 1, new_state}

      caller ->
        GenServer.reply(caller, 1)

        {:reply, 1,
         %{new_state | pending_callers: Map.delete(new_state.pending_callers, :save_undo)}}
    end
  end

  def handle_call(:external_save_undo, from, state) do
    new_state = %{
      state
      | pending_interrupt: 3,
        pending_callers: Map.put(state.pending_callers, :save_undo, from)
    }

    case state.waiting_input do
      nil ->
        {:noreply, new_state}

      waiter ->
        GenServer.reply(waiter, 0x103)
        {:noreply, %{new_state | waiting_input: nil}}
    end
  end

  def handle_call(:restore_undo_get_data, _from, state) do
    case state.undo_stack do
      [] ->
        case Map.get(state.pending_callers, :restore_undo) do
          nil -> :ok
          caller -> GenServer.reply(caller, 0)
        end

        {:reply, nil,
         %{state | pending_callers: Map.delete(state.pending_callers, :restore_undo)}}

      [undone | rest] ->
        new_state = %{state | undo_stack: rest, last_undone: undone}

        case Map.get(new_state.pending_callers, :restore_undo) do
          nil ->
            {:reply, undone, new_state}

          caller ->
            GenServer.reply(caller, 1)

            {:reply, undone,
             %{new_state | pending_callers: Map.delete(new_state.pending_callers, :restore_undo)}}
        end
    end
  end

  def handle_call(:external_restore_undo, from, state) do
    new_state = %{
      state
      | pending_interrupt: 4,
        pending_callers: Map.put(state.pending_callers, :restore_undo, from)
    }

    case state.waiting_input do
      nil ->
        {:noreply, new_state}

      waiter ->
        GenServer.reply(waiter, 0x104)
        {:noreply, %{new_state | waiting_input: nil}}
    end
  end

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
      "zio" =>
        %{
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
          "get_screen_size" =>
            {:fn, [], [:i32],
             fn _ctx ->
               24 <<< 16 ||| 80
             end},
          "check_interrupt" =>
            {:fn, [], [:i32],
             fn _ctx ->
               try do
                 GenServer.call(session_pid, :check_interrupt)
               catch
                 :exit, _ -> 0
               end
             end}
        }
        |> Map.merge(zio_io_imports(session_pid))
        |> Map.merge(zio_screen_imports(session_pid))
        |> Map.merge(zio_state_imports(session_pid))
    }
  end

  defp zio_io_imports(session_pid) do
    %{
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
      "sound_effect" =>
        {:fn, [:i32], [],
         fn _ctx, number ->
           send(session_pid, {:zorb_output, {:sound, number}})
           nil
         end}
    }
  end

  defp zio_screen_imports(session_pid) do
    %{
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
         end}
    }
  end

  defp zio_state_imports(session_pid) do
    %{
      "save" =>
        {:fn, [:i32, :i32, :i32, :i32, :i32], [:i32],
         fn %{caller: caller, memory: memory}, pc, sp, fp, csp, rs ->
           header_bytes = Wasmex.Memory.read_binary(caller, memory, 0x0E, 2)
           <<static_base::16>> = header_bytes

           dynamic_mem = Wasmex.Memory.read_binary(caller, memory, 0, static_base)
           stack = Wasmex.Memory.read_binary(caller, memory, 0x90000, sp * 2)
           call_stack = Wasmex.Memory.read_binary(caller, memory, 0x98000, csp * 2)

           data = %{dynamic_mem: dynamic_mem, stack: stack, call_stack: call_stack}

           try do
             GenServer.call(session_pid, {:save_with_data, data, pc, sp, fp, csp, rs}, :infinity)
           catch
             :exit, _ -> 0
           end
         end},
      "restore" =>
        {:fn, [], [:i32],
         fn %{caller: caller, memory: memory} ->
           try do
             case GenServer.call(session_pid, :restore_get_data, :infinity) do
               nil ->
                 0

               saved ->
                 Wasmex.Memory.write_binary(caller, memory, 0, saved.dynamic_mem)
                 Wasmex.Memory.write_binary(caller, memory, 0x90000, saved.stack)
                 Wasmex.Memory.write_binary(caller, memory, 0x98000, saved.call_stack)
                 1
             end
           catch
             :exit, _ -> 0
           end
         end},
      "save_undo" =>
        {:fn, [:i32, :i32, :i32, :i32, :i32], [:i32],
         fn %{caller: caller, memory: memory}, pc, sp, fp, csp, rs ->
           header_bytes = Wasmex.Memory.read_binary(caller, memory, 0x0E, 2)
           <<static_base::16>> = header_bytes

           dynamic_mem = Wasmex.Memory.read_binary(caller, memory, 0, static_base)
           stack = Wasmex.Memory.read_binary(caller, memory, 0x90000, sp * 2)
           call_stack = Wasmex.Memory.read_binary(caller, memory, 0x98000, csp * 2)

           data = %{dynamic_mem: dynamic_mem, stack: stack, call_stack: call_stack}

           try do
             GenServer.call(
               session_pid,
               {:save_undo_with_data, data, pc, sp, fp, csp, rs},
               :infinity
             )
           catch
             :exit, _ -> 0
           end
         end},
      "restore_undo" =>
        {:fn, [], [:i32],
         fn %{caller: caller, memory: memory} ->
           try do
             case GenServer.call(session_pid, :restore_undo_get_data, :infinity) do
               nil ->
                 0

               undone ->
                 Wasmex.Memory.write_binary(caller, memory, 0, undone.dynamic_mem)
                 Wasmex.Memory.write_binary(caller, memory, 0x90000, undone.stack)
                 Wasmex.Memory.write_binary(caller, memory, 0x98000, undone.call_stack)
                 1
             end
           catch
             :exit, _ -> 0
           end
         end}
    }
    |> Map.merge(zio_state_getters(session_pid))
  end

  defp zio_state_getters(session_pid) do
    %{
      "get_restored_pc" => zio_getter(session_pid, {:get_restored, :pc}),
      "get_restored_sp" => zio_getter(session_pid, {:get_restored, :sp}),
      "get_restored_fp" => zio_getter(session_pid, {:get_restored, :fp}),
      "get_restored_csp" => zio_getter(session_pid, {:get_restored, :csp}),
      "get_restored_random_state" => zio_getter(session_pid, {:get_restored, :rs}),
      "get_undone_pc" => zio_getter(session_pid, {:get_undone, :pc}),
      "get_undone_sp" => zio_getter(session_pid, {:get_undone, :sp}),
      "get_undone_fp" => zio_getter(session_pid, {:get_undone, :fp}),
      "get_undone_csp" => zio_getter(session_pid, {:get_undone, :csp}),
      "get_undone_random_state" => zio_getter(session_pid, {:get_undone, :rs})
    }
  end

  defp zio_getter(session_pid, call) do
    {:fn, [], [:i32],
     fn _ctx ->
       try do
         GenServer.call(session_pid, call)
       catch
         :exit, _ -> 0
       end
     end}
  end

  defp read_string(state, ptr, len) do
    Wasmex.Memory.read_binary(state.store, state.mem, ptr, len)
  end

  defp read_null_terminated_string(state, ptr) do
    binary = Wasmex.Memory.read_binary(state.store, state.mem, ptr, 64)
    [string | _] = :binary.split(binary, <<0>>)
    string
  end
end
