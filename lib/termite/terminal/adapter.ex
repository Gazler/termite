defmodule Termite.Terminal.Adapter do
  @moduledoc """
  The behaviour module for implementing an adapter.
  """

  @doc """
  Start the terminal adapter.
  """
  @callback start(opts :: %{}) :: {:ok, term} | {:error, atom}

  @doc """
  Return a reference for the reader for handling input messages.
  """
  @callback reader(terminal :: term) :: {:ok, reference} | {:error, atom}

  @doc """
  Write a string to the terminal. This function is expected to be implemented
  synchronously in the adapter.
  """
  @callback write(terminal :: term, string :: String.t()) :: {:ok, term} | {:error, atom}
end
