defmodule Termite.Terminal do
  @moduledoc """
  This module provides an interface for interacting with the terminal specified.
  """
  defstruct [:adapter, :reader, :size]

  @doc """
  Start the terminal.

  ## Options

   * `:adapter` - determines the adapter to use. Defaults to `Termite.Terminal.PrimTTY`

  All other options are passed directly to the adapter.
  """
  def start(opts \\ []) do
    {adapter, opts} = Keyword.pop(opts, :adapter, Termite.Terminal.PrimTTY)
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
    {:ok, cols} = :io.columns()
    {:ok, rows} = :io.rows()
    %{state | size: %{width: cols, height: rows}}
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
end
