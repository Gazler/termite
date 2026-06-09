defmodule Termite.Terminal.Shell.SignalHandler do
  @moduledoc false

  alias Termite.Terminal.Shell.DefaultSignalHandler

  @signals %{
    sighup: :hup,
    sigquit: :quit,
    sigabrt: :abrt,
    sigalrm: :alrm,
    sigterm: :term,
    sigusr1: :usr1,
    sigusr2: :usr2,
    sigchld: :chld,
    sigtstp: :tstp,
    sigcont: :cont,
    sigwinch: :winch,
    siginfo: :info
  }

  def install(parent, ref, signals) do
    signal_map =
      signals
      |> normalize_signals()
      |> handle_os_signals()

    if map_size(signal_map) > 0 do
      install_handler(parent, ref, signal_map)
    end
  end

  def uninstall(nil), do: :ok

  def uninstall(%{subscription: subscription}) do
    DefaultSignalHandler.unsubscribe(subscription)
  end

  def uninstall(_handler), do: :ok

  defp install_handler(parent, ref, signal_map) do
    case DefaultSignalHandler.subscribe(parent, ref, signal_map) do
      {:ok, subscription} -> %{subscription: subscription}
      _error -> nil
    end
  end

  defp normalize_signals(:all), do: @signals
  defp normalize_signals(nil), do: %{}
  defp normalize_signals(false), do: %{}
  defp normalize_signals(signal) when is_atom(signal), do: normalize_signals([signal])

  defp normalize_signals(signals) when is_list(signals) do
    signals
    |> Enum.flat_map(&normalize_signal/1)
    |> Map.new()
  end

  defp normalize_signals(_signals), do: %{}

  for {os_signal, signal_name} <- @signals do
    defp normalize_signal(unquote(os_signal)), do: [{unquote(os_signal), unquote(signal_name)}]
    defp normalize_signal(unquote(signal_name)), do: [{unquote(os_signal), unquote(signal_name)}]
  end

  defp normalize_signal(_signal), do: []

  defp handle_os_signals(signal_map) do
    Enum.reduce(signal_map, %{}, fn {os_signal, signal_name}, supported ->
      case handle_os_signal(os_signal) do
        :ok -> Map.put(supported, os_signal, signal_name)
        _error -> supported
      end
    end)
  end

  defp handle_os_signal(signal) do
    :os.set_signal(signal, :handle)
  catch
    _kind, _reason -> :error
  end
end
