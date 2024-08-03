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

  defp seq(:screen_clear, []), do: "J"

  defp seq(:screen_alt, []), do: "?1049h"
  defp seq(:screen_alt_exit, []), do: "?1049l"

  defp seq(:cursor_show, []), do: "?25h"
  defp seq(:cursor_hide, []), do: "?25l"

  defp seq(:reset, []), do: "r"

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

  @doc """
  Write an escape sequence to the terminal.
  """
  def run_escape_sequence(term, command, args \\ []) do
    write(term, escape_sequence(command, args))
  end

  defdelegate write(term, str), to: Termite.Terminal
end
