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

  test "buffers OSC sequences until BEL terminator" do
    ref = make_ref()
    state = %Server{parent: self(), ref: ref, buffer: nil}

    assert {:noreply, %{buffer: "\e"}, 2} = Server.handle_info({:data, "\e"}, state)

    assert {:noreply, %{buffer: "\e]"}, 2} =
             Server.handle_info({:data, "]"}, %{state | buffer: "\e"})

    assert {:noreply, %{buffer: "\e]10;rgb:8383/9494/9696"}, 2} =
             Server.handle_info(
               {:data, "10;rgb:8383/9494/9696"},
               %{state | buffer: "\e]"}
             )

    assert {:noreply, %{buffer: nil}} =
             Server.handle_info(
               {:data, "\a"},
               %{state | buffer: "\e]10;rgb:8383/9494/9696"}
             )

    assert_received {^ref, {:data, "\e]10;rgb:8383/9494/9696\a"}}
  end
end
