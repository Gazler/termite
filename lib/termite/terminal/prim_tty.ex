defmodule Termite.Terminal.PrimTTY do
  @moduledoc """
  A termite adapter for prim_tty provided by OTP.

  This adapter is the default used by Termite.
  """

  @behaviour Termite.Terminal.Adapter

  require Logger
  require Record
  Record.defrecordp(:state, Record.extract(:state, from_lib: "kernel/src/prim_tty.erl"))

  defp from_record(term), do: state(term)

  @doc false
  @impl true
  def reader(term) do
    {_, ref} = from_record(term)[:reader]
    {:ok, ref}
  end

  defp writer(term) do
    from_record(term)[:writer]
  end

  @doc false
  @impl true
  def start(opts \\ []) do
    opts = Map.new(opts)
    :erlang.unregister(:user_drv_writer)
    :erlang.unregister(:user_drv_reader)

    old_level = Logger.level()
    Logger.configure(level: :emergency)
    term = :prim_tty.init(opts)
    :timer.sleep(100)
    Logger.configure(level: old_level)
    {:ok, term}
  end

  @doc false
  @impl true
  def write(term, str) do
    term = state(term, xn: false)
    {output, term} = :prim_tty.handle_request(term, {:putc, str})
    {_pid, ref} = writer(term)
    :prim_tty.write(term, output, self())

    receive do
      {^ref, :ok} -> nil
    end

    {:ok, term}
  end
end
