defmodule Exdistex.PingProviderContract do
  require Logger

  def start_link(message, options \\ []) do
    Exdistex.GenProviderContract.start_link __MODULE__, message, options
  end

  def handle_event(:accepted, state) do
    # {:raise_event, %{"ping" => 42}, state} TODO: We should be able to return actions to perform
    {:ok, state}
  end

  def handle_event(event, state) do
    Logger.info("#{__MODULE__}: event: #{inspect event}, state: #{inspect state}")
    {:ok, state}
  end
end