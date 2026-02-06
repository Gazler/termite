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

  defmodule Winch do
    @behaviour :gen_event

    defstruct [:parent, :ref]

    def init(%__MODULE__{} = state) do
      {:ok, state}
    end

    def handle_call(_, %__MODULE__{} = state) do
      {:ok, :ok, state}
    end

    def handle_event(:sigwinch, %__MODULE__{} = state) do
      send(state.parent, {state.ref, {:signal, :winch}})
      {:ok, state}
    end

    def handle_info(_, %__MODULE__{} = state) do
      {:ok, state}
    end
  end

  defmodule Server do
    use GenServer

    defstruct [:buffer, :parent, :reader, :ref]

    def start_link() do
      GenServer.start_link(__MODULE__, self())
    end

    def ref(pid) do
      GenServer.call(pid, :ref)
    end

    def init(parent) do
      :shell.start_interactive({:noshell, :raw})

      ref = make_ref()

      :os.set_signal(:sigwinch, :handle)
      winch = %Winch{parent: parent, ref: ref}
      :ok = :gen_event.add_handler(:erl_signal_server, Winch, winch)

      {:ok, reader} = Reader.start_link(self(), ref)

      state = %__MODULE__{
        parent: parent,
        reader: reader,
        ref: ref
      }

      {:ok, state}
    end

    def handle_call(:ref, _from, %__MODULE__{} = state) do
      {:reply, state.ref, state}
    end

    def handle_info(:timeout, %__MODULE__{buffer: nil} = state) do
      {:noreply, state}
    end

    def handle_info(:timeout, %__MODULE__{} = state) do
      send(state.parent, {state.ref, {:data, state.buffer}})
      {:noreply, %{state | buffer: nil}}
    end

    def handle_info({:data, "\e"}, %__MODULE__{buffer: nil} = state) do
      {:noreply, %{state | buffer: "\e"}, 50}
    end

    def handle_info({:data, "["}, %__MODULE__{buffer: "\e"} = state) do
      {:noreply, %{state | buffer: "\e["}, 50}
    end

    def handle_info({:data, data}, %__MODULE__{buffer: "\e["} = state) do
      send(state.parent, {state.ref, {:data, "\e[" <> data}})
      {:noreply, %{state | buffer: nil}}
    end

    def handle_info({:data, data}, %__MODULE__{buffer: nil} = state) do
      send(state.parent, {state.ref, {:data, data}})
      {:noreply, %{state | buffer: nil}}
    end
  end

  defstruct [:pid, :ref]

  @impl Adapter
  def start(_ \\ []) do
    {:ok, pid} = Server.start_link()

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
    IO.write(str)
    {:ok, shell}
  end
end
