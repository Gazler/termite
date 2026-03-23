defmodule WatchdogExample do
  alias Termite.Screen

  @log_path Path.join(System.tmp_dir!(), "termite-watchdog-example.log")

  def start() do
    File.rm(@log_path)

    term =
      Termite.Terminal.start(
        watchdog: true,
        watchdog_log: @log_path
      )
      |> Screen.alt_screen()
      |> Screen.hide_cursor()
      |> Screen.enable_mouse(mode: :motion)

    redraw(term)
    loop(term)
  end

  defp loop(term) do
    case Termite.Terminal.poll(term) do
      {:signal, :winch} ->
        term = Termite.Terminal.resize(term)
        redraw(term)
        loop(term)

      {:data, "q"} ->
        term
        |> cleanup()
        |> Termite.Terminal.close()

      _other ->
        loop(term)
    end
  end

  defp redraw(term) do
    body = [
      "Termite watchdog example",
      "",
      "This enables alt-screen, hides the cursor, and enables mouse motion.",
      "To test the watchdog:",
      "1. Run this with: mix run examples/watchdog.exs",
      "2. Press Ctrl+C",
      "3. Choose the abort option in the Erlang break prompt",
      "4. Check whether the shell is clean afterward",
      "",
      "The watchdog restores terminal state, but it does not guarantee",
      "that your shell prompt will redraw immediately after an abort.",
      "",
      "Normal exit: press q",
      "Watchdog log: #{@log_path}"
    ]

    term
    |> Screen.cursor_position(0, 0)
    |> Screen.clear_screen()
    |> Screen.write(Enum.join(body, "\n"))
  end

  defp cleanup(term) do
    term
    |> Screen.disable_mouse()
    |> Screen.show_cursor()
    |> Screen.exit_alt_screen()
    |> Termite.Terminal.write("\r")
  end
end

WatchdogExample.start()
