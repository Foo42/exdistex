defmodule Exdistex.LoggingContract do
  require Logger

  def start_link(expression) do
    Exdistex.GenConsumerContract.start_link expression, __MODULE__
  end

  def handle_event(event, state) do
    Logger.info("#{__MODULE__}: event: #{inspect event}, state: #{inspect state}")
    {:ok, state}
  end
end