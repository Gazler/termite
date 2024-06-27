defmodule Termite.Terminal.PrimTTY do
  require Logger
  require Record
  Record.defrecord(:state, Record.extract(:state, from_lib: "kernel/src/prim_tty.erl"))

  defp from_record(term), do: state(term)

  def reader(term) do
    from_record(term)[:reader]
  end

  def start() do
    :erlang.unregister(:user_drv_writer)
    :erlang.unregister(:user_drv_reader)

    old_level = Logger.level()
    Logger.configure(level: :emergency)
    term = :prim_tty.init(%{})
    :timer.sleep(100)
    Logger.configure(level: old_level)
    term
  end

  def write(term, str) do
    term = state(term, xn: false)
    {output, term} = :prim_tty.handle_request(term, {:putc, str})
    :prim_tty.write(term, output)
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
