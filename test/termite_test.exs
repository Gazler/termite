defmodule TermiteTest do
  use ExUnit.Case
  doctest Termite

  test "greets the world" do
    assert Termite.hello() == :world
  end
end
