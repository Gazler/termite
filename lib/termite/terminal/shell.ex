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

    @escape_timeout 50

    def handle_info(:timeout, %__MODULE__{buffer: nil} = state) do
      {:noreply, state}
    end

    def handle_info(:timeout, %__MODULE__{buffer: buffer} = state) do
      send(state.parent, {state.ref, {:data, buffer}})
      {:noreply, %{state | buffer: nil}}
    end

    def handle_info({:data, data}, %__MODULE__{} = state) when is_binary(data) do
      {state, messages} = buffer_input(state, data)

      Enum.each(messages, fn message ->
        send(state.parent, {state.ref, {:data, message}})
      end)

      if state.buffer == nil do
        {:noreply, state}
      else
        {:noreply, state, @escape_timeout}
      end
    end

    def handle_info({:data, data}, %__MODULE__{} = state) do
      send(state.parent, {state.ref, {:data, to_string(data)}})
      {:noreply, state}
    end

    defp buffer_input(state, data) do
      Enum.reduce(String.graphemes(data), {state, []}, fn char, {state, messages} ->
        case buffer_char(state, char) do
          {state, nil} -> {state, messages}
          {state, message} -> {state, messages ++ [message]}
        end
      end)
    end

    defp buffer_char(%__MODULE__{buffer: nil} = state, "\e") do
      {%{state | buffer: "\e"}, nil}
    end

    defp buffer_char(%__MODULE__{buffer: nil} = state, char) do
      {state, char}
    end

    defp buffer_char(%__MODULE__{buffer: buffer} = state, char) do
      buffer = buffer <> char

      if complete_escape_sequence?(buffer) do
        {%{state | buffer: nil}, buffer}
      else
        {%{state | buffer: buffer}, nil}
      end
    end

    defp complete_escape_sequence?("\e"), do: false
    defp complete_escape_sequence?("\e["), do: false
    defp complete_escape_sequence?("\eO"), do: false

    defp complete_escape_sequence?(<<"\e[", _::binary>> = seq) do
      csi_final_byte?(:binary.last(seq))
    end

    defp complete_escape_sequence?(<<"\e]", _::binary>> = seq) do
      String.ends_with?(seq, "\a") or String.ends_with?(seq, "\e\\")
    end

    defp complete_escape_sequence?(<<"\e", _::binary>>), do: true

    defp csi_final_byte?(byte) when byte >= ?@ and byte <= ?~, do: true
    defp csi_final_byte?(_), do: false
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
    str = str |> String.replace("\r\n", "\n") |> String.replace("\n", "\r\n")
    IO.write(str)
    {:ok, shell}
  end
end
