defmodule Termite.Terminal.PrimTTY do
  @moduledoc """
  A termite adapter for prim_tty provided by OTP.

  This adapter is the default used by Termite.
  """

  @behaviour Termite.Terminal.Adapter

  require Logger
  require Record

  @otp_release String.to_integer(System.otp_release())
  # We need to get the minor release, and we want to represent it as a 4-tuple
  # for easy comparison.
  erts_version =
    :erlang.system_info(:version)
    |> to_string()
    |> String.split(".")
    |> Enum.map(&String.to_integer/1)
    |> then(&(&1 ++ List.duplicate(0, 4 - length(&1))))
    |> List.to_tuple()

  cond do
    @otp_release >= 28 ->
      Record.defrecordp(:state, Record.extract(:state, from: "include/prim_tty_28_0.hrl"))

    @otp_release >= 27 ->
      Record.defrecordp(:state, Record.extract(:state, from: "include/prim_tty_27_0.hrl"))

    # 26.2.5.3 changed the record
    @otp_release >= 26 and erts_version >= {14, 2, 5, 3} ->
      Record.defrecordp(:state, Record.extract(:state, from: "include/prim_tty_26_2_5_3.hrl"))

    @otp_release >= 26 ->
      Record.defrecordp(:state, Record.extract(:state, from: "include/prim_tty_26_0.hrl"))

    true ->
      raise "Unsupported OTP version: #{@otp_release}. Termite requires OTP 26 or later."
  end

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

  @impl true
  def resize(_term) do
    {:ok, cols} = :io.columns()
    {:ok, rows} = :io.rows()
    %{width: cols, height: rows}
  end

  @doc false
  @impl true
  def start(opts \\ []) do
    opts = Map.new(opts)

    if @otp_release >= 28 do
      try do
        :erlang.unregister(:termite_tty)
      rescue
        ArgumentError -> :ok
      end

      :erlang.register(:termite_tty, self())
    else
      try do
        :erlang.unregister(:user_drv_writer)
      rescue
        ArgumentError -> :ok
      end

      try do
        :erlang.unregister(:user_drv_reader)
      rescue
        ArgumentError -> :ok
      end
    end

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
