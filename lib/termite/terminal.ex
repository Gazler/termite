defmodule Termite.Terminal do
  @moduledoc """
  This module provides an interface for interacting with the terminal specified.
  """
  defstruct [:adapter, :reader, :size]

  @doc """
  Start the terminal.

  ## Options

   * `:adapter` - determines the adapter to use. Defaults to `Termite.Terminal.PrimTTY`
     on OTP 27 and below, and `Termite.Terminal.Shell` for OTP 28 and above.

  All other options are passed directly to the adapter.
  """
  def start(opts \\ []) do
    adapter =
      if String.to_integer(System.otp_release()) >= 28 do
        Termite.Terminal.Shell
      else
        Termite.Terminal.PrimTTY
      end

    {adapter, opts} = Keyword.pop(opts, :adapter, adapter)
    {:ok, term} = adapter.start(opts)
    {:ok, ref} = adapter.reader(term)
    resize(%__MODULE__{reader: ref, adapter: {adapter, term}})
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
