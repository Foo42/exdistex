# Think we may need to split this out into a provider, and provider contract modules.
# The provider would listen for requests and call its delegate module to decide whether to handle,
# then it would create a contract process with the contract delegate to accept the contract

# The provider delegate would need a handle? function, and a function for returning the contract module
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
    Exdistex.ProviderRFSM.start_link(message)
    %{state | accepted_contracts: state.accepted_contracts + 1 }
  end
end

defmodule Exdistex.GenProvider do
  def start_link(provider_mod, provider_state \\ %{}, options \\ []) do
    Exdistex.GenRabbitFSM.start_link(__MODULE__, %{provider_mod: provider_mod, provider_state: provider_state}, options)
  end

  def handle_start(%{provider_mod: provider_mod, provider_state: provider_state} = state) do
    initialised_provider_state = provider_mod.init(provider_state)
    {[subscribe: "event.handler.required"], %{state | provider_state: initialised_provider_state}}
  end

  def handle_message({"event.handler.required", message}, state) do
    provider_state = state.provider_mod.event_handler_required message, state.provider_state
    {[], %{state | provider_state: provider_state}}
  end
end

defmodule Exdistex.ProviderRFSM do
  require Logger

  defmodule Messages do
    def handling(state), do: {"#{state.handling_token}.handling", base_message(state)}
    def available(state), do: {"event.handler.available", base_message(state) |> Map.put("handlingToken", state.handling_token)}
    defp base_message(state), do: %{"requestId" => state.request_id, "expression" => state.expression}
  end

  def start_link() do
    Exdistex.GenRabbitFSM.start_link(__MODULE__)
  end

  def start_link(request, options \\ []) do
    Exdistex.GenRabbitFSM.start_link(__MODULE__, request, options)
  end


  def handle_start(%{} = message) do
    %{"requestId" => request_id, "expression" => expression} = message

    handling_token = unique_name

    state = %{}
      |> Map.put(:request_id, request_id)
      |> Map.put(:handling_token, handling_token)
      |> Map.put(:expression, expression)

    actions = [
      subscribe: "#{handling_token}.#",
      publish: Messages.available(state)
    ]

    {actions, state}
  end

  def handle_start(state) do
    actions = [subscribe: "event.handler.required"]
    state = state
      |> Map.put(:state, :unassigned)

    {actions, state}
  end

  def handle_message({"event.handler.required", message}, state) do
    %{"requestId" => request_id, "expression" => expression} = message

    handling_token = unique_name

    state = state
      |> Map.put(:request_id, request_id)
      |> Map.put(:handling_token, handling_token)
      |> Map.put(:expression, expression)

    actions = [
      subscribe: "#{handling_token}.#",
      publish: Messages.available(state)
    ]

    {actions, state}
  end

  def handle_message({message_key, message}, state) when is_binary(message_key) do
    handle_message({String.split(message_key, "."), message}, state)
  end

  def handle_message({[handler, "accept"], message}, %{handling_token: handler} = state) do
      {[publish: Messages.handling(state)], Map.put(state, :state, :accepting)}
  end

  def handle_message(message, state) do
    Logger.debug "#{inspect self}:#{__MODULE__} ignoring message: #{inspect message}"
    {state}
  end

  defp unique_name do
    :erlang.unique_integer |> Integer.to_string |> String.replace("-", "N")
  end
end