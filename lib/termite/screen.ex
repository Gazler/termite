defmodule Termite.Screen do
  @moduledoc """
  This module handles terminal related escape sequences.
  See the source for valid escape sequences.
  """

  defp seq(:cursor_up, [n]), do: "#{n}A"
  defp seq(:cursor_down, [n]), do: "#{n}B"
  defp seq(:cursor_forward, [n]), do: "#{n}C"
  defp seq(:cursor_back, [n]), do: "#{n}D"
  defp seq(:cursor_next_line, [n]), do: "#{n}E"
  defp seq(:cursor_previous_line, [n]), do: "#{n}F"
  defp seq(:cursor_move, [y, x]), do: "#{x};#{y}H"

  defp seq(:screen_clear, []), do: "2J"

  defp seq(:screen_alt, []), do: "?1049h"
  defp seq(:screen_alt_exit, []), do: "?1049l"

  defp seq(:delete_chars, [n]), do: "#{n}P"

  defp seq(:cursor_show, []), do: "?25h"
  defp seq(:cursor_hide, []), do: "?25l"

  defp seq(:mouse_click_enable, []), do: "?1000h"
  defp seq(:mouse_click_disable, []), do: "?1000l"
  defp seq(:mouse_drag_enable, []), do: "?1002h"
  defp seq(:mouse_drag_disable, []), do: "?1002l"
  defp seq(:mouse_motion_enable, []), do: "?1003h"
  defp seq(:mouse_motion_disable, []), do: "?1003l"
  defp seq(:mouse_sgr_enable, []), do: "?1006h"
  defp seq(:mouse_sgr_disable, []), do: "?1006l"

  defp osc_seq(:title, [title]), do: "0;#{title}"
  defp osc_seq(:progress, [state, percent]), do: "9;4;#{state};#{percent}"

  @doc """
  Return the escape code for the terminal.

  ```elixir
  iex> Termite.Screen.escape_code()
  "\e["
  ```
  """
  def escape_code() do
    "\x1b["
  end

  @doc """
  Return an escape sequence.

  ```elixir
  iex> Termite.Screen.escape_sequence(:cursor_back, [3])
  "\e[3D"
  ```
  """
  def escape_sequence(command, args \\ []) do
    escape_code() <> seq(command, args)
  end

  def osc_escape_sequence(command, args \\ []) do
    "\e]" <> osc_seq(command, args)
  end

  @doc """
  Write an escape sequence to the terminal.
  """
  def run_escape_sequence(term, command, args \\ []) do
    write(term, escape_sequence(command, args))
  end

  @doc """
  Move the cursor up by n lines.
  """
  def cursor_up(term, n \\ 1) do
    run_escape_sequence(term, :cursor_up, [n])
  end

  @doc """
  Move the cursor down by n lines.
  """
  def cursor_down(term, n \\ 1) do
    run_escape_sequence(term, :cursor_down, [n])
  end

  @doc """
  Move the cursor forward by n cells.
  """
  def cursor_forward(term, n \\ 1) do
    run_escape_sequence(term, :cursor_forward, [n])
  end

  @doc """
  Move the cursor back by n cells.
  """
  def cursor_back(term, n \\ 1) do
    run_escape_sequence(term, :cursor_back, [n])
  end

  @doc """
  Move the cursor down by n lines and place cursor at the beginning of the line.
  """
  def cursor_next_line(term, n \\ 1) do
    run_escape_sequence(term, :cursor_next_line, [n])
  end

  @doc """
  Move the cursor up by n lines and place cursor at the beginning of the line.
  """
  def cursor_previous_line(term, n \\ 1) do
    run_escape_sequence(term, :cursor_previous_line, [n])
  end

  @doc """
  Set the cursor position to x,y.
  """
  def cursor_position(term, x, y) do
    run_escape_sequence(term, :cursor_move, [x, y])
  end

  @doc """
  Show the cursor.
  """
  def show_cursor(term) do
    run_escape_sequence(term, :cursor_show, [])
  end

  @doc """
  Hide the cursor.
  """
  def hide_cursor(term) do
    run_escape_sequence(term, :cursor_hide, [])
  end

  @doc """
  Clears the screen.
  """
  def clear_screen(term) do
    run_escape_sequence(term, :screen_clear, [])
  end

  @doc """
  Delete the specified number of characters from the cursor.
  """
  def delete_chars(term, n \\ 1) do
    run_escape_sequence(term, :delete_chars, [n])
  end

  @doc """
  Switch to alt screen.
  """
  def alt_screen(term) do
    run_escape_sequence(term, :screen_alt, [])
  end

  @doc """
  Exit to alt screen.
  """
  def exit_alt_screen(term) do
    run_escape_sequence(term, :screen_alt_exit, [])
  end

  @doc """
  Enable mouse tracking.

  ## Options

    * `:mode` - one of `:click` (default), `:drag`, or `:motion`

  `:click` reports clicks/releases and scroll wheel events.
  `:drag` also reports movement while a button is held.
  `:motion` reports all movement.

  SGR mouse mode (`1006`) is enabled automatically.
  """
  def enable_mouse(term, opts \\ []) do
    mode = Keyword.get(opts, :mode, :click)

    term =
      case mode do
        :click ->
          run_escape_sequence(term, :mouse_click_enable, [])

        :drag ->
          term
          |> run_escape_sequence(:mouse_click_enable, [])
          |> run_escape_sequence(:mouse_drag_enable, [])

        :motion ->
          term
          |> run_escape_sequence(:mouse_click_enable, [])
          |> run_escape_sequence(:mouse_motion_enable, [])

        mode ->
          raise ArgumentError,
                "invalid mouse mode #{inspect(mode)}. Expected :click, :drag or :motion"
      end

    run_escape_sequence(term, :mouse_sgr_enable, [])
  end

  @doc """
  Disable mouse tracking and SGR mouse mode.
  """
  def disable_mouse(term) do
    term
    |> run_escape_sequence(:mouse_motion_disable, [])
    |> run_escape_sequence(:mouse_drag_disable, [])
    |> run_escape_sequence(:mouse_click_disable, [])
    |> run_escape_sequence(:mouse_sgr_disable, [])
  end

  @doc """
  Enable enhanced keyboard reporting.

  This currently enables Kitty keyboard protocol basic disambiguation and xterm
  `modifyOtherKeys` mode 2.
  """
  def enable_enhanced_keyboard(term) do
    write(term, "\e[>1u\e[>4;2m")
  end

  @doc """
  Disable enhanced keyboard reporting.
  """
  def disable_enhanced_keyboard(term) do
    write(term, "\e[<u\e[>4;0m")
  end

  @doc """
  Alters the terminal tab or window title. OSC Compatible terminals only.
  """
  def title(term, title) do
    write(term, osc_escape_sequence(:title, [title]))
  end

  @doc """
  Support for OSC Progress Bars https://conemu.github.io/en/AnsiEscapeCodes.html#ConEmu_specific_OSC
  `:clear` - Clear the progress bar
  `:info` - Information state (blue)
  `:error` - Error state (red)
  `:intermediate` - Intermediate state (yellow)
  `:paused` - Paused state (orange)

  progress - Percentage of progress (0-100)
  """
  def progress(term, :clear) do
    write(term, osc_escape_sequence(:progress, [0, 0]))
  end

  def progress(term, :info, progress) do
    write(term, osc_escape_sequence(:progress, [1, progress]))
  end

  def progress(term, :error, progress) do
    write(term, osc_escape_sequence(:progress, [2, progress]))
  end

  def progress(term, :intermediate, progress) do
    write(term, osc_escape_sequence(:progress, [3, progress]))
  end

  def progress(term, :paused, progress) do
    write(term, osc_escape_sequence(:progress, [4, progress]))
  end

  defdelegate write(term, str), to: Termite.Terminal
end
