defmodule Termite.Style do
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

  def ansi(style \\ %Style{}) do
    %{style | type: :ansi}
  end

  def ansi256(style \\ %Style{}) do
    %{style | type: :ansi256}
  end

  def background(%{styles: styles} = style \\ %Style{}, color) do
    %{style | styles: styles ++ [{:background, color}]}
  end

  def foreground(%{styles: styles} = style \\ %Style{}, color) do
    %{style | styles: styles ++ [{:foreground, color}]}
  end

  def bold(%{styles: styles} = style \\ %Style{}) do
    %{style | styles: styles ++ [:bold]}
  end

  def faint(%{styles: styles} = style \\ %Style{}) do
    %{style | styles: styles ++ [:faint]}
  end

  def underline(%{styles: styles} = style \\ %Style{}) do
    %{style | styles: styles ++ [:underline]}
  end

  def blink(%{styles: styles} = style \\ %Style{}) do
    %{style | styles: styles ++ [:blink]}
  end

  def italic(%{styles: styles} = style \\ %Style{}) do
    %{style | styles: styles ++ [:italic]}
  end

  def inverse(%{styles: styles} = style \\ %Style{}) do
    %{style | styles: styles ++ [:inverse]}
  end

  def reverse(%{styles: styles} = style \\ %Style{}) do
    %{style | styles: styles ++ [:inverse]}
  end

  def crossed_out(%{styles: styles} = style \\ %Style{}) do
    %{style | styles: styles ++ [:crossed_out]}
  end

  def reset_code() do
    Termite.Screen.escape_code() <> seq(:reset, %Style{}) <> "m"
  end

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
