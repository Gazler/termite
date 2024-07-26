defmodule Termite.Terminal.PrimTTY do
  require Logger
  require Record
  Record.defrecord(:state, Record.extract(:state, from_lib: "kernel/src/prim_tty.erl"))

  defp from_record(term), do: state(term)

  def reader(term) do
    from_record(term)[:reader]
  end

  def writer(term) do
    from_record(term)[:writer]
  end

  def start(opts \\ %{}) do
    :erlang.unregister(:user_drv_writer)
    :erlang.unregister(:user_drv_reader)

    old_level = Logger.level()
    Logger.configure(level: :emergency)
    term = :prim_tty.init(opts)
    :timer.sleep(100)
    Logger.configure(level: old_level)
    term
  end

  def write(term, str) do
    term = state(term, xn: false)
    {output, term} = :prim_tty.handle_request(term, {:putc, str})
    {_pid, ref} = writer(term)
    :prim_tty.write(term, output, self())

    receive do
      {^ref, :ok} -> nil
    end

    term
  end

  def loop(term, timeout) do
    {_pid, ref} = reader(term)

    receive do
      {^ref, message} -> message
    after
      timeout -> :timeout
    end
  end
end
