defmodule Termite.Input do
  @moduledoc """
  Helpers for parsing raw terminal input into structured events.

  The parser currently supports SGR mouse sequences (`\e[<...M` / `\e[<...m`).
  Unknown input is returned as raw `{:data, binary}`.
  """

  import Bitwise

  @type modifier :: :shift | :alt | :ctrl
  @type mouse_action :: :press | :release | :drag | :move | :scroll

  @type mouse_button ::
          :left
          | :middle
          | :right
          | :none
          | :wheel_up
          | :wheel_down
          | :wheel_left
          | :wheel_right

  @type mouse_event :: %{
          action: mouse_action(),
          button: mouse_button(),
          x: pos_integer(),
          y: pos_integer(),
          modifiers: [modifier()]
        }

  @mouse_sgr_regex ~r/^\e\[<(\d+);(\d+);(\d+)([mM])$/

  @doc """
  Parse a raw `Termite.Terminal.poll/2` message.

  * Mouse sequences are returned as `{:mouse, mouse_event}`.
  * Unknown data is returned as `{:data, binary}`.
  * Non-data messages (like signals) are returned unchanged.
  """
  @spec parse(term()) :: term()
  def parse({:data, data}) when is_binary(data), do: parse_data(data)
  def parse(message), do: message

  @doc """
  Parse raw terminal data.
  """
  @spec parse_data(binary()) :: {:mouse, mouse_event()} | {:data, binary()}
  def parse_data(data) when is_binary(data) do
    case parse_mouse(data) do
      {:ok, event} -> {:mouse, event}
      :error -> {:data, data}
    end
  end

  @doc """
  Parse an SGR mouse sequence (`CSI < ... M` / `CSI < ... m`).

  Returns `{:ok, mouse_event}` on success, otherwise `:error`.
  """
  @spec parse_mouse(binary()) :: {:ok, mouse_event()} | :error
  def parse_mouse(data) when is_binary(data) do
    case Regex.run(@mouse_sgr_regex, data) do
      [_, button_code, x, y, state] ->
        button_code = String.to_integer(button_code)
        x = String.to_integer(x)
        y = String.to_integer(y)

        {:ok, decode_mouse(button_code, x, y, state)}

      _ ->
        :error
    end
  end

  defp decode_mouse(button_code, x, y, state) do
    wheel? = flag?(button_code, 64)
    motion? = flag?(button_code, 32)

    button = decode_button(button_code, wheel?)
    action = decode_action(button, wheel?, motion?, state)

    %{
      action: action,
      button: button,
      x: x,
      y: y,
      modifiers: decode_modifiers(button_code)
    }
  end

  defp decode_action(_button, true, _motion?, _state), do: :scroll
  defp decode_action(_button, false, _motion?, "m"), do: :release
  defp decode_action(:none, false, true, "M"), do: :move
  defp decode_action(_button, false, true, "M"), do: :drag
  defp decode_action(_button, false, false, "M"), do: :press

  defp decode_button(button_code, true) do
    case band(button_code, 0b11) do
      0 -> :wheel_up
      1 -> :wheel_down
      2 -> :wheel_left
      _ -> :wheel_right
    end
  end

  defp decode_button(button_code, false) do
    case band(button_code, 0b11) do
      0 -> :left
      1 -> :middle
      2 -> :right
      _ -> :none
    end
  end

  defp decode_modifiers(button_code) do
    []
    |> maybe_modifier(button_code, 4, :shift)
    |> maybe_modifier(button_code, 8, :alt)
    |> maybe_modifier(button_code, 16, :ctrl)
  end

  defp maybe_modifier(modifiers, value, flag, modifier) do
    if flag?(value, flag), do: modifiers ++ [modifier], else: modifiers
  end

  defp flag?(value, flag), do: band(value, flag) == flag
end
