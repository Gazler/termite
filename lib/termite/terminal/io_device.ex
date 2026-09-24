defmodule Termite.Terminal.IODevice do
  @moduledoc """
  Terminal adapter for an existing Erlang I/O device, such as an SSH shell's
  group leader. The device must support character reads, writes, and the
  `:echo` and `:binary` I/O options. Geometry queries are optional.

      terminal = Termite.Terminal.start(
        adapter: Termite.Terminal.IODevice,
        device: Process.group_leader()
      )

  The adapter disables echo while active and restores the previous I/O options
  when stopped or when its owner exits. It sends input, `:winch`, and `:hup`
  messages through the standard Termite reader reference. Geometry is checked
  every 250 ms when the device supports it.

  This adapter does not switch a physical terminal into raw mode. Use the
  default adapter for a local terminal. Stop the adapter with `Termite.Terminal.stop/1` after
  restoring any screen modes enabled by the application.
  """
  @behaviour Termite.Terminal.Adapter
  use GenServer

  @escape_timeout 20
  @resize_interval 250

  @impl true
  def start(opts) do
    device = Keyword.fetch!(opts, :device)
    ref = make_ref()
    owner = self()

    case GenServer.start(__MODULE__, {owner, device, ref}) do
      {:ok, pid} -> {:ok, %{pid: pid, device: device, ref: ref, owner: owner}}
      error -> error
    end
  end

  @doc "Stops the adapter and restores the device's previous I/O options."
  @impl true
  def stop(%{pid: pid}) do
    GenServer.stop(pid, :normal)
  catch
    :exit, {:noproc, _} -> :ok
    :exit, {:normal, _} -> :ok
  end

  @impl true
  def reader(terminal), do: {:ok, terminal.ref}

  @impl true
  def write(terminal, data) do
    # io.put_chars/2 raises when an SSH device has closed. The protocol request
    # returns an error instead, allowing the router to finish its cleanup.
    case :io.request(terminal.device, {:put_chars, :unicode, data}) do
      :ok -> :ok
      {:error, _} -> send(terminal.owner, {terminal.ref, {:signal, :hup}})
    end

    {:ok, terminal}
  end

  @impl true
  def resize(terminal) do
    with {:ok, width} <- :io.columns(terminal.device),
         {:ok, height} <- :io.rows(terminal.device) do
      %{width: width, height: height}
    else
      _ -> %{width: 80, height: 24}
    end
  end

  @impl true
  def init({owner, device, ref}) do
    Process.monitor(owner)
    Process.monitor(device)

    with opts when is_list(opts) <- :io.getopts(device),
         :ok <- :io.setopts(device, echo: false, binary: true) do
      state = %{
        owner: owner,
        device_alive?: true,
        device: device,
        ref: ref,
        opts: Keyword.take(opts, [:echo, :binary]),
        buffer: "",
        flush_ref: nil,
        size: resize(%{device: device})
      }

      request_input(state)
      Process.send_after(self(), :check_size, @resize_interval)
      {:ok, state}
    else
      error -> {:stop, {:io_device, error}}
    end
  end

  @impl true
  def handle_info({:io_reply, ref, data}, %{ref: ref} = state) when is_binary(data) do
    request_input(state)
    buffer = state.buffer <> data

    if incomplete_escape?(buffer) do
      flush_ref = make_ref()
      Process.send_after(self(), {:flush, flush_ref}, @escape_timeout)
      {:noreply, %{state | buffer: buffer, flush_ref: flush_ref}}
    else
      # An Escape followed by ordinary text is two key presses, not one key.
      case buffer do
        "\e" <> rest when rest != "" ->
          if String.starts_with?(rest, ["[", "]", "O"]) do
            emit(state, buffer)
          else
            emit(state, "\e")
            emit(state, rest)
          end

        _ ->
          emit(state, buffer)
      end

      {:noreply, %{state | buffer: "", flush_ref: nil}}
    end
  end

  def handle_info({:flush, ref}, %{flush_ref: ref} = state) do
    emit(state, state.buffer)
    {:noreply, %{state | buffer: "", flush_ref: nil}}
  end

  def handle_info({:flush, _}, state), do: {:noreply, state}

  def handle_info({:io_reply, ref, _closed}, %{ref: ref} = state) do
    send(state.owner, {ref, {:signal, :hup}})
    {:stop, :normal, state}
  end

  # SSH's I/O protocol exposes geometry but no resize subscription. Poll the
  # session asynchronously so reads, shutdown, and escape timers keep working.
  def handle_info(:check_size, state) do
    for {axis, request} <- [width: :columns, height: :rows] do
      send(state.device, {:io_request, self(), {:geometry, axis}, {:get_geometry, request}})
    end

    Process.send_after(self(), :check_size, @resize_interval)
    {:noreply, state}
  end

  def handle_info({:io_reply, {:geometry, axis}, value}, state)
      when is_integer(value) and value > 0 do
    size = Map.put(state.size, axis, value)
    if size != state.size, do: send(state.owner, {state.ref, {:signal, :winch}})
    {:noreply, %{state | size: size}}
  end

  def handle_info({:io_reply, {:geometry, _}, _}, state), do: {:noreply, state}

  def handle_info({:DOWN, _, :process, device, _}, %{device: device} = state) do
    send(state.owner, {state.ref, {:signal, :hup}})
    {:stop, :normal, %{state | device_alive?: false}}
  end

  def handle_info({:DOWN, _, :process, _, _}, state), do: {:stop, :normal, state}

  @impl true
  def terminate(_reason, state) do
    if state.device_alive?, do: :io.setopts(state.device, state.opts)
    :ok
  catch
    :exit, _ -> :ok
  end

  defp request_input(state) do
    send(state.device, {:io_request, self(), state.ref, {:get_chars, :unicode, "", 1}})
  end

  defp emit(state, data), do: send(state.owner, {state.ref, {:data, data}})

  defp incomplete_escape?("\e"), do: true
  defp incomplete_escape?("\eO"), do: true
  defp incomplete_escape?("\e[" <> rest), do: not Regex.match?(~r/[@-~]$/, rest)
  defp incomplete_escape?("\e]" <> rest), do: not String.ends_with?(rest, ["\a", "\e\\"])
  defp incomplete_escape?(_), do: false
end
