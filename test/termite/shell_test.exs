defmodule Termite.Terminal.ShellTest do
  use ExUnit.Case, async: false

  alias Termite.Terminal.Shell.{DefaultSignalHandler, Server, SignalHandler}

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

  test "signal handler forwards configured signals with normalized names" do
    ensure_default_signal_handler()

    ref = make_ref()
    installed = SignalHandler.install(self(), ref, [:term, :usr1, :usr2])
    on_exit(fn -> SignalHandler.uninstall(installed) end)

    assert installed

    :gen_event.notify(:erl_signal_server, :sigterm)
    assert_receive {^ref, {:signal, :term}}

    :gen_event.notify(:erl_signal_server, :sigusr1)
    assert_receive {^ref, {:signal, :usr1}}

    :gen_event.notify(:erl_signal_server, :sigusr2)
    assert_receive {^ref, {:signal, :usr2}}

    :gen_event.notify(:erl_signal_server, :sigwinch)
    refute_receive {^ref, {:signal, _signal}}, 20
  end

  test "install normalizes short and Erlang signal names" do
    ensure_default_signal_handler()

    ref = make_ref()
    installed = SignalHandler.install(self(), ref, [:winch, :sigusr1])
    on_exit(fn -> SignalHandler.uninstall(installed) end)

    assert installed

    :gen_event.notify(:erl_signal_server, :sigwinch)
    assert_receive {^ref, {:signal, :winch}}

    :gen_event.notify(:erl_signal_server, :sigusr1)
    assert_receive {^ref, {:signal, :usr1}}
  end

  test "uninstall ignores non-installed handlers" do
    assert :ok = SignalHandler.uninstall(:not_installed)
  end

  test "install uses the global handler and removes BEAM default handler for signals it takes over" do
    ensure_default_signal_handler()

    installed = SignalHandler.install(self(), make_ref(), [:usr1])
    handlers = :gen_event.which_handlers(:erl_signal_server)

    assert DefaultSignalHandler in handlers
    refute :erl_signal_handler in handlers

    SignalHandler.uninstall(installed)
    handlers = :gen_event.which_handlers(:erl_signal_server)

    refute DefaultSignalHandler in handlers
    assert :erl_signal_handler in handlers
  end

  test "install leaves BEAM default signal handler in place for non-default signals" do
    ensure_default_signal_handler()

    installed = SignalHandler.install(self(), make_ref(), [:usr2])
    handlers = :gen_event.which_handlers(:erl_signal_server)

    assert DefaultSignalHandler in handlers
    assert :erl_signal_handler in handlers

    SignalHandler.uninstall(installed)
    handlers = :gen_event.which_handlers(:erl_signal_server)

    refute DefaultSignalHandler in handlers
    assert :erl_signal_handler in handlers
  end

  test "install restores BEAM default handler when default signal subscriptions stop" do
    ensure_default_signal_handler()

    non_default = SignalHandler.install(self(), make_ref(), [:usr2])
    term = SignalHandler.install(self(), make_ref(), [:term])

    handlers = :gen_event.which_handlers(:erl_signal_server)
    assert DefaultSignalHandler in handlers
    refute :erl_signal_handler in handlers

    SignalHandler.uninstall(term)

    handlers = :gen_event.which_handlers(:erl_signal_server)
    assert DefaultSignalHandler in handlers
    assert :erl_signal_handler in handlers

    SignalHandler.uninstall(non_default)

    handlers = :gen_event.which_handlers(:erl_signal_server)
    refute DefaultSignalHandler in handlers
    assert :erl_signal_handler in handlers
  end

  test "all signals skips unsupported OS signals" do
    ensure_default_signal_handler()

    ref = make_ref()
    installed = SignalHandler.install(self(), ref, :all)
    on_exit(fn -> SignalHandler.uninstall(installed) end)

    assert installed

    :gen_event.notify(:erl_signal_server, :sigusr2)
    assert_receive {^ref, {:signal, :usr2}}
  end

  test "uninstall restores non-default OS signal disposition" do
    assert {_output, 129} =
             run_signal_child("""
             alias Termite.Terminal.Shell.SignalHandler

             installed = SignalHandler.install(self(), make_ref(), [:hup])
             SignalHandler.uninstall(installed)

             System.cmd("kill", ["-HUP", System.pid()])
             Process.sleep(:infinity)
             """)
  end

  test "uninstall keeps a non-default OS signal handled while another subscription remains" do
    assert {output, 129} =
             run_signal_child("""
             alias Termite.Terminal.Shell.SignalHandler

             ref = make_ref()
             first = SignalHandler.install(self(), make_ref(), [:hup])
             second = SignalHandler.install(self(), ref, [:hup])

             SignalHandler.uninstall(first)
             System.cmd("kill", ["-HUP", System.pid()])

             receive do
               {^ref, {:signal, :hup}} -> IO.write("handled")
             after
               1_000 -> exit(:missing_hup)
             end

             SignalHandler.uninstall(second)
             System.cmd("kill", ["-HUP", System.pid()])
             Process.sleep(:infinity)
             """)

    assert output =~ "handled"
  end

  defp ensure_default_signal_handler do
    if :erl_signal_handler not in :gen_event.which_handlers(:erl_signal_server) do
      :ok = :gen_event.add_handler(:erl_signal_server, :erl_signal_handler, [])
    end
  end

  defp run_signal_child(script) do
    port =
      Port.open({:spawn_executable, System.find_executable("elixir")}, [
        :binary,
        :exit_status,
        :stderr_to_stdout,
        args: ["-pa", Mix.Project.compile_path(), "-e", script]
      ])

    collect_signal_child(port, [])
  end

  defp collect_signal_child(port, output) do
    receive do
      {^port, {:data, data}} ->
        collect_signal_child(port, [data | output])

      {^port, {:exit_status, status}} ->
        {output |> Enum.reverse() |> IO.iodata_to_binary(), status}
    after
      3_000 ->
        kill_signal_child(port)

        flunk("""
        child VM did not exit after receiving SIGHUP

        #{output |> Enum.reverse() |> IO.iodata_to_binary()}
        """)
    end
  end

  defp kill_signal_child(port) do
    case Port.info(port, :os_pid) do
      {:os_pid, os_pid} -> System.cmd("kill", ["-TERM", Integer.to_string(os_pid)])
      nil -> :ok
    end
  end
end
