defmodule Exdistex.LoggingContract do
  require Logger
  def handle_event(event, state) do
    Logger.info("#{__MODULE__}: event: #{inspect event}, state: #{inspect state}")
    {:ok, state}
  end
end