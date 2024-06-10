defmodule Demo do
  alias Termite.Screen

  def start() do
    Termite.Terminal.start()
    |> Screen.run_escape_sequence(:screen_alt)
    |> redraw_and_loop()
  end

  defp redraw_and_loop(state) do
    state |> redraw() |> loop()
  end

  def loop(state) do
    case Termite.Terminal.loop(state) do
      {:signal, :winch} -> redraw_and_loop(Termite.Terminal.resize(state))
      {:data, "\e[A"} -> state |> Screen.run_escape_sequence(:cursor_up, [1]) |> loop()
      {:data, "\e[B"} -> state |> Screen.run_escape_sequence(:cursor_down, [1]) |> loop()
      {:data, "\e[C"} -> state |> Screen.run_escape_sequence(:cursor_forward, [1]) |> loop()
      {:data, "\e[D"} -> state |> Screen.run_escape_sequence(:cursor_back, [1]) |> loop()
      {:data, "q"} -> cleanup_and_exit(state)
      {:data, "r"} -> redraw_and_loop(state)
      _ -> loop(state)
    end
  end

  defp cleanup(state) do
    state
    |> Screen.run_escape_sequence(:reset)
    |> Screen.run_escape_sequence(:screen_alt_exit)
    |> Screen.run_escape_sequence(:screen_clear)
  end

  defp panel(state, str) do
    state = Screen.write(state, "┌" <> String.duplicate("─", state.size.width - 2) <> "┐")

    state =
      Enum.reduce(1..(state.size.height - 2), state, fn _, state ->
        Screen.write(state, "│" <> String.duplicate(" ", state.size.width - 2) <> "│")
      end)

    state = Screen.write(state, "└" <> String.duplicate("─", state.size.width - 2))

    # We write this in a separate command to prevent scrolling
    state = Screen.write(state, "┘")

    # We have to move down and then up again to correctly reset the cursor
    state
    |> Screen.run_escape_sequence(:cursor_move, [3, 0])
    |> Screen.write(str)
    |> Screen.run_escape_sequence(:cursor_move, [3, 3])
  end

  def redraw(state) do
    state
    |> Screen.run_escape_sequence(:cursor_move, [0, 0])
    |> Screen.run_escape_sequence(:screen_clear)
    |> panel("Size: #{state.size.width}x#{state.size.height}")
    |> Screen.write("This is a simple demo")
    |> Screen.run_escape_sequence(:cursor_next_line, [1])
    |> Screen.run_escape_sequence(:cursor_forward, [2])
    |> Screen.write("Press q to Exit")
  end

  defp cleanup_and_exit(state) do
    cleanup(state)
    :timer.sleep(10)
    System.halt()
  end
end

if :erlang.system_info(:break_ignored) != true do
  IO.puts(~s|Run with elixir --erl +"Bi" -S mix run examples/demo.exs|)
  System.halt()
end

Demo.start()
