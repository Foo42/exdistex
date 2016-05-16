defmodule Exdistex.GenConsumerContract do
  require Logger
  def start_link(expression, contract_module, contract_state \\ %{}) do
    params = %{
      expression: expression,
      contract_module: contract_module,
      contract_state: contract_state
    }
    Exdistex.GenRabbitFSM.start_link(__MODULE__, params)
  end

  def begin_watching(pid), do: GenServer.call(pid, {:begin_watching})

  def handle_start(%{expression: expression} = state) do
    request_id = unique_name
    actions = [subscribe: "event.handler.available", publish: {"event.handler.required", %{"expression" => expression, "requestId" => request_id}}]
    state = state
      |> Map.put(:request_id, request_id)
      |> Map.put(:state, :requested)
      |> process_contract_event(:init)
    {:actions, actions, state}
  end

  def handle_start(state) do
    {state}
  end

  defp process_contract_event(state, event) do
    {:ok, contract_state} = state.contract_module.handle_event(event, state.contract_state)
    %{state | contract_state: contract_state}
  end

  def perform_action(:begin_watching, state) do
    Logger.debug "performing begin_watching, state: #{inspect state}"
    actions = [publish:
      {"#{state.handler}.watch",
        %{
          "handlingToken" => state.handler,
          "expression" => state.expression
        }
      }
    ]
    {:actions, actions, state}
  end

  def handle_message({"event.handler.available", %{"requestId" => request_id} = message}, %{request_id: request_id} = state) do
    %{"handlingToken" => handler} = message
    state = state
      |> Map.put(:handler, handler)
      |> Map.put(:state, :accepting)

    actions = [
      subscribe: "#{handler}.#",
      publish: {"#{handler}.accept",%{
        "handlingToken" => handler,
        "expression" => state.expression
      }}
    ]
    {:actions, actions, state}
  end

  def handle_message({message_key, %{"requestId" => request_id} = message}, state) when is_binary(message_key) do
    handle_message({String.split(message_key, "."), message}, state)
  end

  def handle_message({[_,"handling"],message}, %{state: :accepting} = state) do
    state
      |> Map.put(:state, :handled)
      |> process_contract_event(:handled)
    {state}
  end

  def handle_message({[_,"watching"], _message}, state), do: {process_contract_event(state, :watching)}
  def handle_message({[_,"notWatching"], _message}, state), do: {process_contract_event(state, :not_watching)}
  def handle_message({[_,"event"], message}, state), do: {process_contract_event(state, {:event, message["event"]})}

  def handle_message(message, state) do
    Logger.debug "#{inspect self}:#{__MODULE__} ignoring message: #{inspect message} with current state #{inspect state}"
    {state}
  end

  def handle_call({:begin_watching}, _from, state) do
    {:actions, [:begin_watching], :reply, :ok, state}
  end

  def handle_call(message, from, state) do
    message
      |> state.contract_module.handle_call(from, state.contract_state)
      |> Tuple.to_list()
      |> List.update_at(-1, &%{state | contract_state: &1})
      |> List.to_tuple()
  end

  defp unique_name do
    :erlang.unique_integer |> Integer.to_string |> String.replace("-", "N")
  end
end