defmodule CtrlCExample do
  alias Termite.Screen

  def start() do
    term =
      Termite.Terminal.start()
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

      {:data, "\x03"} ->
        cleanup_and_exit(term, "Handled Ctrl+C as input (\\x03)")

      {:data, "q"} ->
        cleanup_and_exit(term, "Handled q")

      _other ->
        loop(term)
    end
  end

  defp redraw(term) do
    body = [
      "Termite Ctrl+C example",
      "",
      "Run this with:",
      "elixir --erl \"+Bc\" -S mix run examples/ctrl_c.exs",
      "",
      "This example enables mouse motion mode so you can verify",
      "that mouse escape sequences are not left active after exit.",
      "",
      "Ctrl+C will be delivered as input (\\x03) instead of opening",
      "the default Erlang break prompt.",
      "",
      "Press q to exit normally."
    ]

    term
    |> Screen.cursor_position(0, 0)
    |> Screen.clear_screen()
    |> Screen.write(Enum.join(body, "\n"))
  end

  defp cleanup_and_exit(term, message) do
    term
    |> Screen.disable_mouse()
    |> Screen.show_cursor()
    |> Screen.exit_alt_screen()
    |> Termite.Terminal.write("\r" <> message <> "\n")

    System.halt(0)
  end
end

CtrlCExample.start()
