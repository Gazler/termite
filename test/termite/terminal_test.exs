defmodule Termite.TerminalTest do
  use ExUnit.Case, async: true

  alias Termite.Terminal

  defmodule LegacyAdapter do
    @behaviour Termite.Terminal.Adapter

    @impl true
    def start(_opts), do: {:ok, make_ref()}
    @impl true
    def reader(ref), do: {:ok, ref}
    @impl true
    def write(ref, _data), do: {:ok, ref}
    @impl true
    def resize(_ref), do: %{width: 80, height: 24}
  end

  test "stop accepts adapters without the optional callback" do
    terminal = Terminal.start(adapter: LegacyAdapter)

    refute function_exported?(LegacyAdapter, :stop, 1)
    assert :ok = Terminal.stop(terminal)
  end
end
