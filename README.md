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

## Installation

Termite requires OTP-26 or above, but is best supported on OTP 28.

He package can be installed by adding `termite` to your list of dependencies in
`mix.exs`:

```elixir
def deps do
  [
    {:termite, "~> 0.3.0"}
  ]
end
```

## Examples

It is not recommended to call `Termite.Terminal.start/1` in `iex`. Use a script
instead.

For development, `mix run` is convenient, and you can enable the watchdog to
restore terminal state after an abnormal exit:

```elixir
term = Termite.Terminal.start(watchdog: true)
```

The watchdog is best-effort and intended for development ergonomics. It can
restore mouse mode, cursor visibility, and alt-screen state after a crash or
BEAM abort, but it does not guarantee that your shell prompt will redraw
immediately.

The `examples/watchdog.exs` script shows a standalone watchdog setup you can try
directly during development.

For production, prefer starting without the default Erlang break prompt
behavior. If you are launching through Mix, you can use:

```sh
elixir --erl "+Bc" -S mix run examples/ctrl_c.exs
```

`+Bc` makes `Ctrl+C` interrupt the current shell instead of invoking the default
emulator break handler. The `examples/ctrl_c.exs` script shows how to handle
`Ctrl+C` as the input byte `\x03` under `+Bc`.

See the Erlang docs for details:
https://erlang.org/documentation/doc-7.2/erts-7.2/doc/html/erl.html

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

terminal

More examples are available in the examples directory.

## Documentation

https://hexdocs.pm/termite

Documentation can be generated with ExDoc using:

```sh
mix docs
```
