defmodule Termite.Terminal.IODeviceTest do
  use ExUnit.Case, async: true

  alias Termite.Terminal
  alias Termite.Terminal.IODevice

  setup do
    owner = self()
    device = spawn_link(fn -> device_loop(owner, echo: true, binary: false) end)
    on_exit(fn -> if Process.alive?(device), do: Process.exit(device, :kill) end)
    %{device: device}
  end

  test "uses the supplied device and restores its options on stop", %{device: device} do
    terminal = Terminal.start(adapter: IODevice, device: device)
    {IODevice, adapter} = terminal.adapter
    assert terminal.size == %{width: 80, height: 24}
    assert :io.getopts(device) == [echo: false, binary: true]

    Terminal.write(terminal, "hello")
    assert_receive {:written, "hello"}
    send(device, {:input, "x"})
    assert Terminal.poll(terminal, 1_000) == {:data, "x"}

    assert :ok = Terminal.stop(terminal)
    assert :io.getopts(device) == [echo: true, binary: false]
    refute Process.alive?(adapter.pid)
    assert :ok = Terminal.stop(terminal)
  end

  test "buffers split escape sequences and reports disconnection", %{device: device} do
    terminal = Terminal.start(adapter: IODevice, device: device)
    send(device, {:input, "\e"})
    send(device, {:input, "["})
    send(device, {:input, "A"})
    assert Terminal.poll(terminal, 1_000) == {:data, "\e[A"}

    Process.unlink(device)
    Process.exit(device, :kill)
    assert Terminal.poll(terminal, 1_000) == {:signal, :hup}
  end

  test "restores the device when the terminal owner dies", %{device: device} do
    parent = self()

    owner =
      spawn(fn ->
        terminal = Terminal.start(adapter: IODevice, device: device)
        send(parent, {:terminal, terminal})

        receive do
          :stop -> :ok
        end
      end)

    assert_receive {:terminal, terminal}
    {IODevice, adapter} = terminal.adapter
    ref = Process.monitor(adapter.pid)
    send(owner, :stop)
    assert_receive {:DOWN, ^ref, :process, _, :normal}
    assert :io.getopts(device) == [echo: true, binary: false]
  end

  # Minimal I/O protocol device; these tests do not start a physical terminal.
  defp device_loop(owner, opts, reader \\ nil, input \\ []) do
    receive do
      {:io_request, from, ref, {:get_chars, :unicode, "", 1}} ->
        deliver(owner, opts, {from, ref}, input)

      {:input, data} ->
        deliver(owner, opts, reader, input ++ [data])

      {:io_request, from, ref, request} ->
        {reply, opts} =
          case request do
            :getopts ->
              {opts, opts}

            {:setopts, updates} ->
              {:ok, Keyword.merge(opts, updates)}

            {:get_geometry, :columns} ->
              {80, opts}

            {:get_geometry, :rows} ->
              {24, opts}

            {:put_chars, :unicode, data} ->
              send(owner, {:written, data})
              {:ok, opts}
          end

        send(from, {:io_reply, ref, reply})
        device_loop(owner, opts, reader, input)
    end
  end

  defp deliver(owner, opts, {from, ref}, [data | rest]) do
    send(from, {:io_reply, ref, data})
    device_loop(owner, opts, nil, rest)
  end

  defp deliver(owner, opts, reader, input), do: device_loop(owner, opts, reader, input)
end
