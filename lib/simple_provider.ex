defmodule Exdistex.SimpleProvider do
  require Logger

  def start_link(options \\ []) do
    Exdistex.GenProvider.start_link(__MODULE__, options)
  end

  def init(params) do
    %{accepted_contracts: 0}
  end

  def event_handler_required(message, state) do
    Logger.info "#{__MODULE__} accepting contract"
    Exdistex.GenProviderContract.start_link(message)
    %{state | accepted_contracts: state.accepted_contracts + 1 }
  end
end