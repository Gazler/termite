defmodule Termite.Terminal do
  @moduledoc """
  This module provides an interface for interacting with the terminal specified.
  """
  defstruct [:adapter, :reader, :size, :watchdog]

  @doc """
  Start the terminal.

  ## Options

   * `:adapter` - determines the adapter to use. Defaults to `Termite.Terminal.PrimTTY`
     on OTP 27 and below, and `Termite.Terminal.Shell` for OTP 28 and above.
   * `:watchdog` - on Unix, start an external helper that can restore terminal
     state if the BEAM exits before normal cleanup. Defaults to `false`

  All other options are passed directly to the adapter.
  """
  def start(opts \\ []) do
    adapter =
      if String.to_integer(System.otp_release()) >= 28 do
        Termite.Terminal.Shell
      else
        Termite.Terminal.PrimTTY
      end

    {watchdog?, opts} = Keyword.pop(opts, :watchdog, false)
    {watchdog_script, opts} = Keyword.pop(opts, :watchdog_script)
    {watchdog_tty, opts} = Keyword.pop(opts, :watchdog_tty)
    {watchdog_args, opts} = Keyword.pop(opts, :watchdog_args, [])
    {watchdog_log, opts} = Keyword.pop(opts, :watchdog_log)
    {adapter, opts} = Keyword.pop(opts, :adapter, adapter)
    {:ok, term} = adapter.start(opts)
    {:ok, ref} = adapter.reader(term)

    watchdog =
      if watchdog? do
        Termite.Terminal.Watchdog.start(
          script: watchdog_script,
          tty_path: watchdog_tty,
          extra_args: watchdog_args,
          log_path: watchdog_log
        )
      end

    resize(%__MODULE__{reader: ref, adapter: {adapter, term}, watchdog: watchdog})
  end

  @doc """
  Write a string to the terminal.

  See `Termite.Screen` and `Termite.Style` for documentation on escape codes.
  """
  def write(state, str) do
    %{adapter: {adapter, term}} = state
    {:ok, term} = adapter.write(term, str)
    %{state | adapter: {adapter, term}}
  end

  @doc """
  Update the size of the terminal.
  """
  def resize(state) do
    %{adapter: {adapter, term}} = state
    %{state | size: safe_resize(adapter, term, state.size)}
  end

  @doc """
  Wait for input from the terminal.
  """
  def poll(state, timeout \\ :infinity) do
    %{reader: ref} = state

    receive do
      {^ref, message} -> message
    after
      timeout -> :timeout
    end
  end

  @doc """
  Disarm any active watchdog after normal shutdown.
  """
  def close(%__MODULE__{watchdog: watchdog} = state) do
    Termite.Terminal.Watchdog.disarm(watchdog)
    %{state | watchdog: nil}
  end

  defp safe_resize(adapter, term, fallback) do
    case adapter.resize(term) do
      %{width: width, height: height} when is_integer(width) and is_integer(height) ->
        %{width: width, height: height}

      {:error, _reason} ->
        fallback || %{width: 80, height: 24}
    end
  rescue
    MatchError ->
      fallback || %{width: 80, height: 24}
  end
end
