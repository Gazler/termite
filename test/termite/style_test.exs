defmodule Termite.StyleTest do
  use ExUnit.Case, async: true

  describe "sequences" do
    test "sequences are combined" do
      style =
        Termite.Style.bold()
        |> Termite.Style.italic()
        |> Termite.Style.foreground(5)
        |> Termite.Style.background(3)

      assert style.styles == [:bold, :italic, {:foreground, 5}, {:background, 3}]
    end

    test "sequences rendered to a string" do
      string =
        Termite.Style.bold()
        |> Termite.Style.italic()
        |> Termite.Style.blink()
        |> Termite.Style.render_to_string("hello world")

      assert string == "\e[1;3;5mhello world\e[0m"
    end

    test "no escape codes if there are no styles" do
      string = Termite.Style.render_to_string("hello world")

      assert string == "hello world"
    end
  end

  describe "colors" do
    test "ansi colors are supported by default" do
      string =
        Termite.Style.foreground(5)
        |> Termite.Style.background(3)
        |> Termite.Style.render_to_string("hello world")

      assert string == "\e[35;43mhello world\e[0m"
    end

    test "bright ansi colors are supported" do
      string =
        Termite.Style.foreground(11)
        |> Termite.Style.background(13)
        |> Termite.Style.render_to_string("hello world")

      assert string == "\e[93;105mhello world\e[0m"
    end

    test "extended ansi colors are supported if specified" do
      string =
        Termite.Style.ansi256()
        |> Termite.Style.foreground(50)
        |> Termite.Style.background(33)
        |> Termite.Style.render_to_string("hello world")

      assert string == "\e[38;5;50;48;5;33mhello world\e[0m"
    end

    test "extended ansi colors raise by default" do
      assert_raise(FunctionClauseError, fn ->
        Termite.Style.foreground(50)
        |> Termite.Style.background(33)
        |> Termite.Style.render_to_string("hello world")
      end)
    end
  end
end
