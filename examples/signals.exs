defmodule Signals do
  alias Termite.Screen

  @default_signals [:winch, :term, :quit, :usr1]
  @known_signals [:winch, :term, :quit, :usr1]

  def start(args \\ System.argv()) do
    signals = parse_signals(args)

    Termite.Terminal.start(signals: signals)
    |> Screen.title("Termite Signals")
    |> redraw(signals, [])
    |> loop(signals, [])
  end

  defp loop(terminal, signals, events) do
    case Termite.Terminal.poll(terminal) do
      {:signal, :winch} ->
        events = [{:winch, "terminal resized"} | events]

        terminal
        |> Termite.Terminal.resize()
        |> redraw(signals, events)
        |> loop(signals, events)

      {:signal, signal} ->
        message = signal_message(signal)
        events = [{signal, message} | events]

        terminal
        |> redraw(signals, events)
        |> loop(signals, events)

      {:data, "q"} ->
        cleanup_and_exit(terminal)

      _event ->
        loop(terminal, signals, events)
    end
  end

  defp redraw(terminal, signals, events) do
    terminal
    |> Screen.run_escape_sequence(:cursor_move, [0, 0])
    |> Screen.run_escape_sequence(:screen_clear)
    |> Screen.write("""
    Termite signal example

    PID: #{System.pid()}
    Signals: #{inspect(signals)}

    Run these from another terminal:

      kill -WINCH #{System.pid()}  # send :winch
      kill -TERM  #{System.pid()}  # send :term
      kill -QUIT  #{System.pid()}  # send :quit, normally halts BEAM
      kill -USR1  #{System.pid()}  # send :usr1, normally halts BEAM
      kill -KILL  #{System.pid()}  # force stop, cannot be captured

    Press q here to exit.

    Events:
    #{format_events(events)}
    """)
  end

  defp parse_signals([]), do: @default_signals

  defp parse_signals(args) do
    args
    |> Enum.flat_map(&String.split(&1, ",", trim: true))
    |> Enum.map(&String.trim_leading(&1, ":"))
    |> Enum.flat_map(&parse_signal/1)
  end

  for signal <- @known_signals do
    name = Atom.to_string(signal)
    os_name = "sig" <> name

    defp parse_signal(unquote(name)), do: [unquote(signal)]
    defp parse_signal(unquote(os_name)), do: [unquote(signal)]
  end

  defp parse_signal(_signal), do: []

  defp signal_message(:term), do: "captured SIGTERM"
  defp signal_message(:quit), do: "captured SIGQUIT instead of halting"
  defp signal_message(:usr1), do: "captured SIGUSR1 instead of halting"
  defp signal_message(signal), do: "captured #{inspect(signal)}"

  defp format_events([]), do: "  waiting...\n"

  defp format_events(events) do
    events
    |> Enum.take(10)
    |> Enum.map_join("\n", fn {signal, message} -> "  #{inspect(signal)} - #{message}" end)
  end

  defp cleanup_and_exit(terminal) do
    terminal
    |> Screen.run_escape_sequence(:screen_clear)
    |> Screen.progress(:clear)

    :timer.sleep(10)
    System.halt()
  end
end

Signals.start()
