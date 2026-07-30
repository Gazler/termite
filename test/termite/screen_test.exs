defmodule Termite.ScreenTest do
  use ExUnit.Case, async: true
  doctest Termite.Screen

  alias Termite.Screen

  defmodule TestAdapter do
    def write(pid, data) do
      send(pid, {:terminal_write, data})
      {:ok, pid}
    end
  end

  test "enhanced keyboard writes the keyboard reporting sequences" do
    terminal = %Termite.Terminal{adapter: {TestAdapter, self()}}

    assert Screen.escape_sequence(:enhanced_keyboard_enable) == "\e[>1u\e[>4;2m"
    assert Screen.escape_sequence(:enhanced_keyboard_disable) == "\e[<u\e[>4;0m"

    assert %Termite.Terminal{} = Screen.enable_enhanced_keyboard(terminal)
    assert_receive {:terminal_write, "\e[>1u\e[>4;2m"}

    assert %Termite.Terminal{} = Screen.disable_enhanced_keyboard(terminal)
    assert_receive {:terminal_write, "\e[<u\e[>4;0m"}
  end
end
