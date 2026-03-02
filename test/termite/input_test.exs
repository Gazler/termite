defmodule Termite.InputTest do
  use ExUnit.Case, async: true

  alias Termite.Input

  describe "parse_mouse/1" do
    test "parses left click" do
      assert {:ok, %{action: :press, button: :left, x: 12, y: 7, modifiers: []}} ==
               Input.parse_mouse("\e[<0;12;7M")
    end

    test "parses release" do
      assert {:ok, %{action: :release, button: :left, x: 12, y: 7, modifiers: []}} ==
               Input.parse_mouse("\e[<0;12;7m")
    end

    test "parses drag" do
      assert {:ok, %{action: :drag, button: :left, x: 5, y: 9, modifiers: []}} ==
               Input.parse_mouse("\e[<32;5;9M")
    end

    test "parses movement without button" do
      assert {:ok, %{action: :move, button: :none, x: 5, y: 9, modifiers: []}} ==
               Input.parse_mouse("\e[<35;5;9M")
    end

    test "parses wheel scrolling" do
      assert {:ok, %{action: :scroll, button: :wheel_up, x: 10, y: 3, modifiers: []}} ==
               Input.parse_mouse("\e[<64;10;3M")

      assert {:ok, %{action: :scroll, button: :wheel_down, x: 10, y: 3, modifiers: []}} ==
               Input.parse_mouse("\e[<65;10;3M")
    end

    test "parses modifiers" do
      assert {:ok, %{action: :press, button: :left, x: 2, y: 1, modifiers: [:shift, :alt, :ctrl]}} ==
               Input.parse_mouse("\e[<28;2;1M")
    end

    test "returns error for non-mouse input" do
      assert :error == Input.parse_mouse("q")
    end
  end

  describe "parse/1" do
    test "returns parsed mouse event" do
      assert {:mouse, %{action: :press, button: :left, x: 1, y: 1, modifiers: []}} ==
               Input.parse({:data, "\e[<0;1;1M"})
    end

    test "returns unknown data unchanged" do
      assert {:data, "q"} == Input.parse({:data, "q"})
    end

    test "returns non-data messages unchanged" do
      assert {:signal, :winch} == Input.parse({:signal, :winch})
      assert :timeout == Input.parse(:timeout)
    end
  end
end
