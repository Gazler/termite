defmodule Termite.Terminal.WatchdogTest do
  use ExUnit.Case, async: true

  alias Termite.Terminal

  defmodule FakeAdapter do
    @behaviour Termite.Terminal.Adapter

    def start(_opts) do
      {:ok, %{ref: make_ref(), size: %{width: 80, height: 24}}}
    end

    def reader(term), do: {:ok, term.ref}
    def resize(term), do: term.size
    def write(term, _str), do: {:ok, term}
  end

  test "close clears an active watchdog after launch" do
    tmp_dir =
      Path.join(System.tmp_dir!(), "termite-watchdog-test-#{System.unique_integer([:positive])}")

    File.mkdir_p!(tmp_dir)

    marker_path = Path.join(tmp_dir, "marker.txt")
    script_path = Path.join(tmp_dir, "watchdog.sh")

    File.write!(script_path, """
    #!/bin/sh
    parent_pid="$1"
    disarm_path="$3"
    marker_path="$5"

    echo started >> "$marker_path"

    while kill -0 "$parent_pid" 2>/dev/null; do
      [ -e "$disarm_path" ] && break
      sleep 0.05
    done

    [ -e "$disarm_path" ] && echo disarmed >> "$marker_path"
    """)

    term =
      Terminal.start(
        adapter: FakeAdapter,
        watchdog: true,
        watchdog_script: script_path,
        watchdog_args: [marker_path]
      )

    assert eventually?(fn ->
             File.exists?(marker_path) and String.contains?(File.read!(marker_path), "started")
           end)

    assert %Terminal{watchdog: nil} = Terminal.close(term)
  end

  defp eventually?(fun, attempts \\ 40)

  defp eventually?(fun, attempts) when attempts > 0 do
    if fun.() do
      true
    else
      Process.sleep(50)
      eventually?(fun, attempts - 1)
    end
  end

  defp eventually?(_fun, 0), do: false
end
