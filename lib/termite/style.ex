defmodule Termite.Style do
  @moduledoc """
  This module contains functions for building up a styled input.

  The functions in this module are intended to be chained. For example:

  ```elixir
  iex> Termite.Style.background(5)
  ...> |> Termite.Style.foreground(3)
  ...> |> Termite.Style.bold()
  ...> |> Termite.Style.render_to_string("Hello World")
  "\e[1;45;33mHello World\e[0m"
  ```
  """

  alias __MODULE__

  defstruct styles: [], type: :ansi

  defp seq(:reset, _), do: "0"
  defp seq(:bold, _), do: "1"
  defp seq(:faint, _), do: "2"
  defp seq(:italic, _), do: "3"
  defp seq(:underline, _), do: "4"
  defp seq(:blink, _), do: "5"
  defp seq(:inverse, _), do: "7"
  defp seq(:crossed_out, _), do: "9"
  defp seq({:background, color}, style), do: color(style, color, :background)
  defp seq({:foreground, color}, style), do: color(style, color, :foreground)

  defp color(%Style{type: :ansi}, color, type) when color < 16 do
    color = color + if color < 8, do: 30, else: 82
    color + if type == :background, do: 10, else: 0
  end

  defp color(%Style{type: :ansi256}, color, :background) do
    "48;5;#{color}"
  end

  defp color(%Style{type: :ansi256}, color, :foreground) do
    "38;5;#{color}"
  end

  @doc """
  Change the style type to ansi. This is the default value.
  """
  def ansi(style \\ %Style{}) do
    %{style | type: :ansi}
  end

  @doc """
  Change the style type to ansi256 for extended colors.
  """
  def ansi256(style \\ %Style{}) do
    %{style | type: :ansi256}
  end

  @doc """
  Set the background color. This can be a value up to 16 for `:ansi`
  or up to 255 for `:ansi256`.
  """
  def background(%{styles: styles} = style \\ %Style{}, color) do
    %{style | styles: styles ++ [{:background, color}]}
  end

  @doc """
  Set the foreground (text) color. This can be a value up to 16 for `:ansi`
  or up to 255 for `:ansi256`.
  """
  def foreground(%{styles: styles} = style \\ %Style{}, color) do
    %{style | styles: styles ++ [{:foreground, color}]}
  end

  @doc """
  Set the text style to bold.
  """
  def bold(%{styles: styles} = style \\ %Style{}) do
    %{style | styles: styles ++ [:bold]}
  end

  @doc """
  Set the text style to dim/faint.
  """
  def faint(%{styles: styles} = style \\ %Style{}) do
    %{style | styles: styles ++ [:faint]}
  end

  @doc """
  Set the text style to underline.
  """
  def underline(%{styles: styles} = style \\ %Style{}) do
    %{style | styles: styles ++ [:underline]}
  end

  @doc """
  Set the text style to blink.
  """
  def blink(%{styles: styles} = style \\ %Style{}) do
    %{style | styles: styles ++ [:blink]}
  end

  @doc """
  Set the text style to italic.
  """
  def italic(%{styles: styles} = style \\ %Style{}) do
    %{style | styles: styles ++ [:italic]}
  end

  @doc """
  Set the text style to inverse (swap foreground/background colors).
  """
  def inverse(%{styles: styles} = style \\ %Style{}) do
    %{style | styles: styles ++ [:inverse]}
  end

  @doc """
  Set the text style to inverse (swap foreground/background colors).
  """
  def reverse(%{styles: styles} = style \\ %Style{}) do
    %{style | styles: styles ++ [:inverse]}
  end

  @doc """
  Set the text style to strikethrough.
  """
  def crossed_out(%{styles: styles} = style \\ %Style{}) do
    %{style | styles: styles ++ [:crossed_out]}
  end

  @doc """
  Output the reset code.

  ```elixir
  iex> Termite.Style.reset_code()
  "\e[0m"
  ```
  """
  def reset_code() do
    Termite.Screen.escape_code() <> seq(:reset, %Style{}) <> "m"
  end

  @doc """
  Render a string with the specified styles. And a reset code.

  ```elixir
  iex> Termite.Style.bold()
  ...> |> Termite.Style.render_to_string("Hello")
  "\e[1mHello\e[0m"
  ```
  """
  def render_to_string(style \\ %Style{}, str)

  def render_to_string(%Style{styles: []}, str) do
    str
  end

  def render_to_string(style = %Style{}, str) do
    seq =
      style.styles
      |> Enum.sort()
      |> Enum.map(&seq(&1, style))
      |> Enum.join(";")

    Termite.Screen.escape_code() <>
      seq <> "m" <> str <> reset_code()
  end
end
