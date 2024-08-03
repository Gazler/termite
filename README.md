# Termite

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

Termite requires OTP-26 or above.

He package can be installed by adding `termite` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:termite, "~> 0.2.0"}
  ]
end
```

## Examples

It is not recommended to call Termite.Terminal.start() in iex, instead create a script and run it
using `mix run` as it can change the way the terminal works which isn't entirely compatible with
iex.

```elixir
Mix.install([{:termite, "~> 0.2.0"}]

styled =
  Termite.Style.bold()
  |> Termite.Style.foreground(3)
  |> Termite.Style.background(5)
  |> Termite.Style.render_to_string("I am bold\n")

Termite.Terminal.start()
|> Termite.Screen.run_escape_sequence(:reset)
|> Termite.Screen.run_escape_sequence(:screen_clear)
|> Termite.Screen.write("\n\n\n")
|> Termite.Screen.run_escape_sequence(:cursor_previous_line, [3])
|> Termite.Screen.write("Hello world")
|> Termite.Screen.run_escape_sequence(:cursor_next_line, [3])
|> Termite.Screen.write(styled)

```

More examples are available in the examples directory.

## Documentation

Documentation can be generated with ExDoc using:

```sh
ex_doc Termite 0.2.0 _build/dev/lib/termite/ebin/
```
