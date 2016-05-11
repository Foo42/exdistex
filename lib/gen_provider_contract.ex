defmodule Exdistex.GenProviderContract do
  require Logger

  defmodule Messages do
    def handling(state), do: {"#{state.handling_token}.handling", base_message(state)}
    def watching(state), do: {"#{state.handling_token}.watching", base_message(state)}
    def available(state), do: {"event.handler.available", base_message(state) |> Map.put("handlingToken", state.handling_token)}
    defp base_message(state), do: %{"requestId" => state.request_id, "expression" => state.expression}
  end

  def start_link(contract_module, request, options \\ []) do
    Exdistex.GenRabbitFSM.start_link(__MODULE__, %{contract_module: contract_module, request: request}, options)
  end

  def handle_start(%{contract_module: contract_module, request: request} = params) do
    %{"requestId" => request_id, "expression" => expression} = request

    handling_token = unique_name

    state = %{}
      |> Map.put(:contract_module, contract_module)
      |> Map.put(:request_id, request_id)
      |> Map.put(:handling_token, handling_token)
      |> Map.put(:expression, expression)
      |> Map.put(:contract_state, expression)
      |> process_contract_event(:init)

    actions = [
      subscribe: "#{handling_token}.#",
      publish: Messages.available(state)
    ]

    {:actions, actions, state}
  end

# Do this in consumer contract too
  defp process_contract_event(state, event) do
    {:ok, contract_state} = state.contract_module.handle_event(event, state.contract_state)
    %{state | contract_state: contract_state}
  end

  def handle_message({message_key, message}, state) when is_binary(message_key) do
    handle_message({String.split(message_key, "."), message}, state)
  end

  def handle_message({[handler, "accept"], message}, %{handling_token: handler} = state) do
      new_state = state
        |> Map.put(:state, :accepted)
        |> process_contract_event(:accepted)

      {:actions, [publish: Messages.handling(state)], new_state}
  end

  def handle_message({[handler, "watch"], message}, %{handling_token: handler} = state) do
      new_state = state
        |> Map.put(:state, :watching)
        |> process_contract_event(:watching)

      {:actions, [publish: Messages.watching(state)], new_state}
  end

  def handle_message(message, state) do
    Logger.debug "#{inspect self}:#{__MODULE__} ignoring message: #{inspect message}"
    {state}
  end

  def handle_call(message, from, state) do
    message
      |> state.contract_module.handle_call(from, state.contract_state)
      |> Tuple.to_list()
      |> List.update_at(-1, &%{state | contract_state: &1})
      |> List.to_tuple()
  end

  def perform_action({:send_event, event}, state) do
    Logger.debug "performing send event action"
    actions = [publish:
      {"#{state.handling_token}.event",
        %{
          "handlingToken" => state.handling_token,
          "requestId" => state.request_id,
          "expression" => state.expression,
          "event" => event
        }
      }
    ]
    {:ok, actions, state}
  end

  defp unique_name do
    :erlang.unique_integer |> Integer.to_string |> String.replace("-", "N")
  end
end