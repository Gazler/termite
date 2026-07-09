defmodule Termite.Terminal.Shell do
  @behaviour Termite.Terminal.Adapter

  alias Termite.Terminal.Adapter

  defmodule Reader do
    use GenServer

    defstruct [:parent, :ref]

    def start_link(parent, ref) do
      state = %__MODULE__{parent: parent, ref: ref}
      GenServer.start_link(__MODULE__, state)
    end

    def init(%__MODULE__{} = state) do
      {:ok, state, {:continue, :poll}}
    end

    def handle_continue(:poll, %__MODULE__{} = state) do
      case IO.getn("") do
        :eof ->
          {:noreply, state, {:continue, :poll}}

        {:error, _} ->
          {:noreply, state, {:continue, :poll}}

        data ->
          send(state.parent, {:data, data})
          {:noreply, state, {:continue, :poll}}
      end
    end
  end

  defmodule Server do
    use GenServer

    alias Termite.Terminal.Shell.SignalHandler

    defstruct [:buffer, :parent, :reader, :ref, :signal_handler]

    def start_link(opts \\ []) do
      GenServer.start_link(__MODULE__, {self(), opts})
    end

    def ref(pid) do
      GenServer.call(pid, :ref)
    end

    def init({parent, opts}) do
      Process.flag(:trap_exit, true)
      :shell.start_interactive({:noshell, :raw})

      ref = make_ref()
      signal_handler = SignalHandler.install(parent, ref, Keyword.get(opts, :signals, [:winch]))

      {:ok, reader} = Reader.start_link(self(), ref)

      state = %__MODULE__{
        parent: parent,
        reader: reader,
        ref: ref,
        signal_handler: signal_handler
      }

      {:ok, state}
    end

    def terminate(_reason, %__MODULE__{} = state) do
      SignalHandler.uninstall(state.signal_handler)
      :ok
    end

    def handle_call(:ref, _from, %__MODULE__{} = state) do
      {:reply, state.ref, state}
    end

    @escape_timeout 2

    def handle_info(:timeout, %__MODULE__{buffer: nil} = state) do
      {:noreply, state}
    end

    def handle_info(:timeout, %__MODULE__{} = state) do
      send(state.parent, {state.ref, {:data, state.buffer}})
      {:noreply, %{state | buffer: nil}}
    end

    def handle_info({:data, "\e"}, %__MODULE__{buffer: nil} = state) do
      {:noreply, %{state | buffer: "\e"}, @escape_timeout}
    end

    def handle_info({:data, "["}, %__MODULE__{buffer: "\e"} = state) do
      {:noreply, %{state | buffer: "\e["}, @escape_timeout}
    end

    def handle_info({:data, "]"}, %__MODULE__{buffer: "\e"} = state) do
      {:noreply, %{state | buffer: "\e]"}, @escape_timeout}
    end

    def handle_info({:data, "O"}, %__MODULE__{buffer: "\e"} = state) do
      {:noreply, %{state | buffer: "\eO"}, @escape_timeout}
    end

    def handle_info({:data, data}, %__MODULE__{buffer: "\e"} = state) do
      send(state.parent, {state.ref, {:data, "\e"}})
      send(state.parent, {state.ref, {:data, data}})
      {:noreply, %{state | buffer: nil}}
    end

    def handle_info({:data, data}, %__MODULE__{buffer: buffer} = state)
        when is_binary(buffer) and buffer != "\e" do
      new_buffer = buffer <> data

      if complete_escape_sequence?(new_buffer) do
        send(state.parent, {state.ref, {:data, new_buffer}})
        {:noreply, %{state | buffer: nil}}
      else
        {:noreply, %{state | buffer: new_buffer}, @escape_timeout}
      end
    end

    def handle_info({:data, data}, %__MODULE__{buffer: nil} = state) do
      send(state.parent, {state.ref, {:data, data}})
      {:noreply, state}
    end

    defp complete_escape_sequence?("\e[" <> rest) when rest != "" do
      csi_final_byte?(String.last(rest))
    end

    defp complete_escape_sequence?("\e]" <> rest) when rest != "" do
      osc_terminated?(rest)
    end

    defp complete_escape_sequence?("\eO" <> rest) when rest != "" do
      ss3_final_byte?(String.last(rest))
    end

    defp complete_escape_sequence?(_), do: false

    defp csi_final_byte?(<<byte>>) when byte >= ?@ and byte <= ?~, do: true
    defp csi_final_byte?(_), do: false

    defp osc_terminated?(rest) do
      String.ends_with?(rest, "\a") or String.ends_with?(rest, "\e\\")
    end

    defp ss3_final_byte?(<<byte>>) when byte >= ?@ and byte <= ?~, do: true
    defp ss3_final_byte?(_), do: false
  end

  defstruct [:pid, :ref]

  @impl Adapter
  def start(opts \\ []) do
    {:ok, pid} = Server.start_link(opts)

    shell = %__MODULE__{
      pid: pid,
      ref: Server.ref(pid)
    }

    {:ok, shell}
  end

  @impl Adapter
  def reader(%__MODULE__{} = shell) do
    {:ok, shell.ref}
  end

  @impl Adapter
  def resize(%__MODULE__{}) do
    {:ok, cols} = :io.columns()
    {:ok, rows} = :io.rows()
    %{width: cols, height: rows}
  end

  @impl Adapter
  def write(%__MODULE__{} = shell, str) do
    str = str |> String.replace("\r\n", "\n") |> String.replace("\n", "\r\n")
    IO.write(str)
    {:ok, shell}
  end
end
