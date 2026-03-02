defmodule Mouse do
  alias Termite.Screen

  @hard_signals [:sigterm, :sighup, :sigquit]

  def start() do
    install_emergency_cleanup()
    install_hard_signal_cleanup()

    term =
      Termite.Terminal.start()
      |> Screen.alt_screen()
      |> Screen.hide_cursor()
      |> Screen.enable_mouse(mode: :click)
      |> redraw("Click/scroll mouse. Press q to quit (recommended). Ctrl+C also exits.")

    try do
      loop(term)
    after
      cleanup(term)
    end
  end

  defp install_emergency_cleanup() do
    System.at_exit(fn _status ->
      IO.write(Screen.restore_sequence())
    end)
  end

  defp install_hard_signal_cleanup() do
    Enum.each(@hard_signals, fn signal ->
      _ =
        System.trap_signal(signal, fn ->
          IO.write(Screen.restore_sequence())
          System.stop(0)
        end)
    end)
  end

  defp redraw(term, message) do
    term
    |> Screen.run_escape_sequence(:cursor_move, [0, 0])
    |> Screen.clear_screen()
    |> Screen.write(message)
    |> Screen.run_escape_sequence(:cursor_next_line, [2])
    |> Screen.write("Mouse mode: click | q: quit | Ctrl+C: quit | Ctrl+C Ctrl+C may hard-abort")
  end

  defp loop(term) do
    case Termite.Terminal.poll_event(term) do
      {:mouse, event} ->
        message =
          "#{event.action} #{event.button} at (#{event.x}, #{event.y}) mods=#{inspect(event.modifiers)}"

        term |> redraw(message) |> loop()

      {:data, "q"} ->
        :ok

      {:data, <<3>>} ->
        :ok

      _ ->
        loop(term)
    end
  end

  defp cleanup(_term) do
    Screen.emergency_restore()
    :ok
  end
end

Mouse.start()
