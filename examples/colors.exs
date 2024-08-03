defmodule Colors do
  def start() do
    Termite.Terminal.start()
    |> draw()
  end

  def draw(term) do
    str = Termite.Style.bold() |> Termite.Style.render_to_string("Basic ANSI Colors\n")

    term = Termite.Screen.write(term, str)

    term =
      Enum.reduce(0..15, term, fn i, acc ->
        foreground = if i < 5, do: 7, else: 0

        str =
          Termite.Style.background(i)
          |> Termite.Style.foreground(foreground)
          |> Termite.Style.render_to_string(" #{String.pad_leading(to_string(i), 2, " ")}   ")

        str =
          if i == 7 do
            str <> "\n"
          else
            str
          end

        Termite.Screen.write(acc, str)
      end)

    str = Termite.Style.bold() |> Termite.Style.render_to_string("\n\nExtended ANSI Colors\n")

    term = Termite.Screen.write(term, str)

    Enum.reduce(16..231, term, fn i, acc ->
      foreground = if i < 28, do: 7, else: 0

      str =
        Termite.Style.ansi256()
        |> Termite.Style.background(i)
        |> Termite.Style.foreground(foreground)
        |> Termite.Style.render_to_string(" #{String.pad_leading(to_string(i), 3, " ")}   ")

      str =
        if rem(i - 16, 6) == 5 do
          str <> "\n"
        else
          str
        end

      Termite.Screen.write(acc, str)
    end)

    str = Termite.Style.bold() |> Termite.Style.render_to_string("\n\Extended ANSI Grayscale\n")

    term = Termite.Screen.write(term, str)

    Enum.reduce(232..255, term, fn i, acc ->
      foreground = if i < 244, do: 7, else: 0

      str =
        Termite.Style.ansi256()
        |> Termite.Style.background(i)
        |> Termite.Style.foreground(foreground)
        |> Termite.Style.render_to_string(" #{String.pad_leading(to_string(i), 3, " ")}   ")

      str =
        if rem(i - 232, 6) == 5 do
          str <> "\n"
        else
          str
        end

      Termite.Screen.write(acc, str)
    end)

    Termite.Screen.write(term, "\n")
  end
end

Colors.start()
