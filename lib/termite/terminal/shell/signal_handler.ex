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

  @beam_default_signals [:sigquit, :sigterm, :sigusr1]
  @state_key {__MODULE__, :os_signals}

  def install(parent, ref, signals) do
    signal_map =
      signals
      |> normalize_signals()
      |> acquire_os_signals()

    if map_size(signal_map) > 0 do
      install_handler(parent, ref, signal_map)
    end
  end

  def uninstall(nil), do: :ok

  def uninstall(%{subscription: subscription, signals: signals}) do
    try do
      DefaultSignalHandler.unsubscribe(subscription)
    after
      release_os_signals(signals)
    end
  end

  def uninstall(%{subscription: subscription}) do
    DefaultSignalHandler.unsubscribe(subscription)
  end

  def uninstall(_handler), do: :ok

  defp install_handler(parent, ref, signal_map) do
    case DefaultSignalHandler.subscribe(parent, ref, signal_map) do
      {:ok, subscription} ->
        %{subscription: subscription, signals: Map.keys(signal_map)}

      _error ->
        release_os_signals(Map.keys(signal_map))
        nil
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

  defp acquire_os_signals(signal_map) do
    :global.trans({__MODULE__, :lock}, fn ->
      {signal_map, state} =
        Enum.reduce(signal_map, {%{}, os_signal_state()}, fn {os_signal, signal_name},
                                                             {supported, state} ->
          case acquire_os_signal(state, os_signal) do
            {:ok, state} -> {Map.put(supported, os_signal, signal_name), state}
            {:error, state} -> {supported, state}
          end
        end)

      store_os_signal_state(state)
      signal_map
    end)
  end

  defp acquire_os_signal(state, signal) do
    case Map.fetch(state, signal) do
      {:ok, count} ->
        {:ok, Map.put(state, signal, count + 1)}

      :error ->
        case handle_os_signal(signal) do
          :ok -> {:ok, Map.put(state, signal, 1)}
          _error -> {:error, state}
        end
    end
  end

  defp release_os_signals(signals) do
    :global.trans({__MODULE__, :lock}, fn ->
      signals
      |> Enum.reduce(os_signal_state(), &release_os_signal/2)
      |> store_os_signal_state()

      :ok
    end)
  end

  defp release_os_signal(signal, state) do
    case Map.fetch(state, signal) do
      {:ok, count} when count > 1 ->
        Map.put(state, signal, count - 1)

      {:ok, 1} ->
        restore_os_signal(signal)
        Map.delete(state, signal)

      :error ->
        state
    end
  end

  defp handle_os_signal(signal) do
    :os.set_signal(signal, :handle)
  catch
    _kind, _reason -> :error
  end

  defp restore_os_signal(signal) when signal in @beam_default_signals, do: :ok

  defp restore_os_signal(signal) do
    :os.set_signal(signal, :default)
  catch
    _kind, _reason -> :error
  end

  defp os_signal_state do
    :persistent_term.get(@state_key, %{})
  end

  defp store_os_signal_state(state) when map_size(state) == 0 do
    :persistent_term.erase(@state_key)
  end

  defp store_os_signal_state(state), do: :persistent_term.put(@state_key, state)
end
