defmodule Termite.Terminal.Watchdog do
  @moduledoc false

  defstruct [:disarm_path]

  def start(opts) do
    if unix?() do
      do_start(opts)
    end
  rescue
    _ -> nil
  end

  def disarm(nil), do: :ok

  def disarm(%__MODULE__{disarm_path: disarm_path}) do
    File.write(disarm_path, "")
    :ok
  rescue
    _ -> :ok
  end

  defp do_start(opts) do
    script = opts[:script] || default_script_path()
    tty_path = tty_path(Keyword.get(opts, :tty_path))
    extra_args = Keyword.get(opts, :extra_args, [])
    log_path = Keyword.get(opts, :log_path)
    disarm_path = disarm_path()
    File.rm(disarm_path)

    maybe_log(
      log_path,
      "launch-attempt pid=#{os_pid()} tty=#{tty_path} script=#{script}"
    )

    args = [script, os_pid(), tty_path, disarm_path, log_path || ""] ++ extra_args

    case launch(args) do
      :ok ->
        maybe_log(log_path, "launch-ok")
        %__MODULE__{disarm_path: disarm_path}

      :error ->
        maybe_log(log_path, "launch-error")
        nil
    end
  end

  defp launch(args) do
    cond do
      File.exists?("/usr/bin/setsid") ->
        run_launcher("/usr/bin/setsid", ["-f", "/bin/sh" | args])

      File.exists?("/usr/bin/nohup") ->
        run_launcher(
          "/bin/sh",
          ["-c", "nohup /bin/sh \"$@\" >/dev/null 2>&1 </dev/null &", "termite-watchdog" | args]
        )

      true ->
        :error
    end
  end

  defp run_launcher(executable, args) do
    _port =
      Port.open(
        {:spawn_executable, executable},
        [
          :binary,
          args: args
        ]
      )

    :ok
  end

  defp default_script_path do
    Application.app_dir(:termite, "priv/watchdog.sh")
  end

  defp tty_path(nil) do
    fd_tty_path(1) || fd_tty_path(0) || command_tty_path(1) || command_tty_path(0) || "/dev/tty"
  end

  defp tty_path(path), do: path

  defp fd_tty_path(fd) do
    path = "/proc/self/fd/#{fd}"

    case File.read_link(path) do
      {:ok, target} when is_binary(target) ->
        if String.starts_with?(target, "/dev/") do
          target
        end

      _other ->
        nil
    end
  rescue
    _ -> nil
  end

  defp command_tty_path(fd) when fd in [0, 1] do
    case System.cmd("/bin/sh", ["-c", "tty <&#{fd}"], stderr_to_stdout: true) do
      {output, 0} ->
        output
        |> String.trim()
        |> normalize_tty_path()

      _other ->
        nil
    end
  rescue
    _ -> nil
  end

  defp normalize_tty_path(path) do
    if String.starts_with?(path, "/dev/") do
      path
    end
  end

  defp disarm_path do
    base = System.tmp_dir!()
    unique = :erlang.unique_integer([:positive, :monotonic])
    Path.join(base, "termite-watchdog-#{os_pid()}-#{unique}.disarm")
  end

  defp os_pid do
    :os.getpid()
    |> List.to_string()
    |> normalize_pid()
    |> case do
      nil -> command_parent_pid()
      pid -> pid
    end
  end

  defp maybe_log(nil, _message), do: :ok

  defp maybe_log(path, message) do
    File.write(path, message <> "\n", [:append])
    :ok
  rescue
    _ -> :ok
  end

  defp unix? do
    match?({:unix, _}, :os.type())
  end

  defp command_parent_pid do
    case System.cmd("/bin/sh", ["-c", "printf '%s' \"$PPID\""], stderr_to_stdout: true) do
      {output, 0} ->
        normalize_pid(String.trim(output))

      _other ->
        nil
    end
  rescue
    _ -> nil
  end

  defp normalize_pid(pid) when is_binary(pid) do
    pid = String.trim(pid)

    if pid != "" and String.match?(pid, ~r/^\d+$/) do
      pid
    end
  end
end
