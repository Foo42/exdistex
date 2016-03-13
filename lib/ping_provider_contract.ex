defmodule Exdistex.PingProviderContract do
  require Logger

  def start_link(message, options \\ []) do
    Exdistex.GenProviderContract.start_link __MODULE__, message, options
  end

  def handle_event(event, state) do
    Logger.info("#{__MODULE__}: event: #{inspect event}, state: #{inspect state}")
    {:ok, state}
  end
end