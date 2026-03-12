defmodule Termite.Terminal.ShellTest do
  use ExUnit.Case, async: true

  alias Termite.Terminal.Shell.Server

  test "buffers SS3 function key sequences until complete" do
    ref = make_ref()
    state = %Server{parent: self(), ref: ref, buffer: nil}

    assert {:noreply, %{buffer: "\e"}, 2} = Server.handle_info({:data, "\e"}, state)

    assert {:noreply, %{buffer: "\eO"}, 2} =
             Server.handle_info({:data, "O"}, %{state | buffer: "\e"})

    assert {:noreply, %{buffer: nil}} =
             Server.handle_info({:data, "P"}, %{state | buffer: "\eO"})

    assert_received {^ref, {:data, "\eOP"}}
  end
end
