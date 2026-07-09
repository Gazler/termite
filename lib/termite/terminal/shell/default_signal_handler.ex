defmodule Termite.Terminal.Shell.DefaultSignalHandler do
  @moduledoc false

  @behaviour :gen_event

  @handler __MODULE__
  @default_handler :erl_signal_handler
  @default_signals [:sigquit, :sigterm, :sigusr1]
  @state_key {__MODULE__, :state}

  def subscribe(parent, ref, signal_map) when map_size(signal_map) > 0 do
    id = make_ref()

    :global.trans({__MODULE__, :lock}, fn ->
      with {:ok, state} <- ensure_handler_installed(state(), Map.keys(signal_map)) do
        state =
          put_subscription(state, id, parent, ref, signal_map)

        store_state(state)
        {:ok, id}
      end
    end)
  end

  def unsubscribe(nil), do: :ok

  def unsubscribe(id) do
    :global.trans({__MODULE__, :lock}, fn ->
      state =
        state()
        |> delete_subscription(id)

      if map_size(state.subscriptions) == 0 do
        uninstall_last_subscription(state)
      else
        state = maybe_restore_default_handler(state)
        store_state(state)
      end

      :ok
    end)
  end

  @impl :gen_event
  def init(_args) do
    {:ok, []}
  end

  @impl :gen_event
  def handle_event(signal, handler_state) do
    state = state()

    unless dispatch_signal(signal, state.subscriptions) do
      delegate_default_signal(signal, state.default_handler)
    end

    {:ok, handler_state}
  end

  @impl :gen_event
  def handle_call(_request, handler_state) do
    {:ok, :ok, handler_state}
  end

  @impl :gen_event
  def handle_info(_message, handler_state) do
    {:ok, handler_state}
  end

  @impl :gen_event
  def terminate(_reason, _handler_state) do
    :ok
  end

  defp initial_state do
    %{subscriptions: %{}, default_handler: :none}
  end

  defp state do
    :persistent_term.get(@state_key, initial_state())
  end

  defp put_subscription(state, id, parent, ref, signal_map) do
    subscription = %{parent: parent, ref: ref, signals: signal_map}
    %{state | subscriptions: Map.put(state.subscriptions, id, subscription)}
  end

  defp delete_subscription(state, id) do
    %{state | subscriptions: Map.delete(state.subscriptions, id)}
  end

  defp store_state(state), do: :persistent_term.put(@state_key, state)
  defp erase_state, do: :persistent_term.erase(@state_key)

  defp ensure_handler_installed(state, signals) do
    cond do
      handler_installed?(@handler) ->
        {:ok, maybe_take_over_default_handler(state, signals)}

      default_handler_required?(signals) ->
        take_over_default_handler(state)

      true ->
        add_handler(state)
    end
  end

  defp add_handler(state) do
    case :gen_event.add_handler(:erl_signal_server, @handler, []) do
      :ok -> {:ok, state}
      {:error, :already_present} -> {:ok, state}
      _error -> {:error, :add_failed}
    end
  end

  defp take_over_default_handler(state) do
    restore? = handler_installed?(@default_handler)

    case :gen_event.swap_handler(
           :erl_signal_server,
           {@default_handler, :take_over},
           {@handler, []}
         ) do
      :ok -> {:ok, put_default_handler(state, restore?)}
      _error -> {:error, :swap_failed}
    end
  end

  defp maybe_take_over_default_handler(%{default_handler: :none} = state, signals) do
    if default_handler_required?(signals) and handler_installed?(@default_handler) do
      delete_handler(@default_handler)
      put_default_handler(state, true)
    else
      state
    end
  end

  defp maybe_take_over_default_handler(state, _signals), do: state

  defp put_default_handler(state, true) do
    %{state | default_handler: %{restore?: true, state: default_handler_state()}}
  end

  defp put_default_handler(state, false), do: state

  defp maybe_restore_default_handler(state) do
    if default_handler_unused?(state) do
      restore_default_handler(state)
    else
      state
    end
  end

  defp restore_default_handler(%{default_handler: %{restore?: true}} = state) do
    state = %{state | default_handler: :none}
    store_state(state)

    unless handler_installed?(@default_handler) do
      _ = :gen_event.add_handler(:erl_signal_server, @default_handler, [])
    end

    state
  end

  defp restore_default_handler(%{default_handler: %{restore?: false}} = state) do
    %{state | default_handler: :none}
  end

  defp restore_default_handler(state), do: state

  defp uninstall_last_subscription(%{default_handler: %{restore?: true}} = state) do
    state = %{state | default_handler: :none}
    store_state(state)

    _ =
      :gen_event.swap_handler(
        :erl_signal_server,
        {@handler, :restore_default},
        {@default_handler, []}
      )

    erase_state()
  end

  defp uninstall_last_subscription(_state) do
    delete_handler(@handler)
    erase_state()
  end

  defp default_handler_unused?(%{default_handler: :none}), do: false

  defp default_handler_unused?(state) do
    state.subscriptions
    |> Map.values()
    |> Enum.flat_map(&Map.keys(&1.signals))
    |> default_handler_required?()
    |> Kernel.not()
  end

  defp default_handler_required?(signals) do
    Enum.any?(signals, &(&1 in @default_signals))
  end

  defp dispatch_signal(signal, subscriptions) do
    Enum.reduce(subscriptions, false, fn {_id, subscription}, delivered? ->
      case Map.fetch(subscription.signals, signal) do
        {:ok, signal_name} ->
          send(subscription.parent, {subscription.ref, {:signal, signal_name}})
          true

        :error ->
          delivered?
      end
    end)
  end

  defp delegate_default_signal(signal, %{state: default_state}) do
    _ = apply(@default_handler, :handle_event, [signal, default_state])
    :ok
  end

  defp delegate_default_signal(_signal, _default_handler), do: :ok

  defp default_handler_state do
    case apply(@default_handler, :init, [[]]) do
      {:ok, default_state} -> default_state
      _other -> []
    end
  end

  defp handler_installed?(handler), do: handler in :gen_event.which_handlers(:erl_signal_server)

  defp delete_handler(handler) do
    _ = :gen_event.delete_handler(:erl_signal_server, handler, :normal)
    :ok
  end
end
