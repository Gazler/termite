defmodule Termite.Terminal do
  defstruct [:adapter, :size]

  def start(opts \\ []) do
    adapter = Keyword.get(opts, :adapter, Termite.Terminal.PrimTTY)
    term = adapter.start()
    resize(%__MODULE__{adapter: {adapter, term}})
  end

  def write(state, str) do
    %{adapter: {adapter, term}} = state
    term = adapter.write(term, str)
    %{state | adapter: {adapter, term}}
  end

  def resize(state) do
    {:ok, cols} = :io.columns()
    {:ok, rows} = :io.rows()
    %{state | size: %{width: cols, height: rows}}
  end

  def loop(state, timeout \\ :infinity) do
    %{adapter: {adapter, term}} = state
    adapter.loop(term, timeout)
  end
end
