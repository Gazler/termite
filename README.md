# 🪳 Termite

A dependency-free NIF-free terminal library for Elixir.

## Features

 * no dependencies
 * no NIF required by default
 * Is tty
 * support for cursor navigation
 * support for text styles
 * support for ANSI and ANSI-256 styles
 * support for alt screen
 * support for keyboard events
 * support for mouse events (click, scroll, position)

## Installation

Termite requires OTP-26 or above.

He package can be installed by adding `termite` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:termite, "~> 0.3.0"}
  ]
end
```

## Examples

It is not recommended to call Termite.Terminal.start() in iex, instead create a script and run it
using `mix run` as it can change the way the terminal works which isn't entirely compatible with
iex.

```elixir
Mix.install([{:termite, "~> 0.3.0"}])

styled =
  Termite.Style.bold()
  |> Termite.Style.foreground(3)
  |> Termite.Style.background(5)
  |> Termite.Style.render_to_string("I am bold\n")

Termite.Terminal.start()
  |> Termite.Screen.clear_screen()
  |> Termite.Screen.cursor_position(0, 0)
  |> Termite.Screen.write(styled)
  |> tap(fn _ -> :timer.sleep(1000) end)
  |> Termite.Screen.alt_screen()
  |> Termite.Screen.cursor_position(10, 3)
  |> Termite.Screen.write("I'm on an alt screen")
  |> tap(fn _ -> :timer.sleep(1000) end)
  |> Termite.Screen.exit_alt_screen()

```

Mouse events:

```elixir
term =
  Termite.Terminal.start()
  |> Termite.Screen.enable_mouse(mode: :click)

case Termite.Terminal.poll_event(term) do
  {:mouse, %{action: :scroll, button: :wheel_up, x: x, y: y}} ->
    IO.puts("scroll up at #{x},#{y}")

  {:mouse, %{action: :press, button: :left, x: x, y: y}} ->
    IO.puts("left click at #{x},#{y}")
end
```

See `examples/mouse.exs` for a full example.

- press `q` to quit cleanly (recommended)
- `Ctrl+C` is handled (`^C`) and restores the terminal in normal raw-input mode
- `Ctrl+C Ctrl+C` can force BEAM abort (`SIGINT` break path), which can skip in-VM cleanup
- best-effort hard signal cleanup is installed for `SIGTERM`, `SIGHUP`, and `SIGQUIT`
- if you need external exit trapping, run `./examples/mouse.sh` (shell trap + tty restore)
- `SIGKILL` cannot be trapped and cannot run cleanup
- if your terminal is left dirty after a hard abort, run:
  - `mix run -e 'Termite.Screen.emergency_restore()'`
  - and if needed: `stty sane`

   terminal

More examples are available in the examples directory.

## Documentation

https://hexdocs.pm/termite

Documentation can be generated with ExDoc using:

```sh
mix docs
```
