defmodule Termite.ScreenMouseTest do
  use ExUnit.Case, async: true

  alias Termite.Screen

  test "mouse tracking escape sequences" do
    assert Screen.escape_sequence(:mouse_click_enable) == "\e[?1000h"
    assert Screen.escape_sequence(:mouse_click_disable) == "\e[?1000l"
    assert Screen.escape_sequence(:mouse_drag_enable) == "\e[?1002h"
    assert Screen.escape_sequence(:mouse_drag_disable) == "\e[?1002l"
    assert Screen.escape_sequence(:mouse_motion_enable) == "\e[?1003h"
    assert Screen.escape_sequence(:mouse_motion_disable) == "\e[?1003l"
    assert Screen.escape_sequence(:mouse_sgr_enable) == "\e[?1006h"
    assert Screen.escape_sequence(:mouse_sgr_disable) == "\e[?1006l"
  end

  test "restore sequence includes mouse disable + cursor + reset + alt exit" do
    assert Screen.restore_sequence() ==
             "\e[?1003l\e[?1002l\e[?1000l\e[?1006l\e[?25h\e[0m\e[?1049l"
  end
end
