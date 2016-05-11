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
      |> Map.put(:contract_state, state.contract_module.handle_event(:init, state.contract_state))
    {:actions, actions, state}
  end

  def handle_start(state) do
    {state}
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
    state =
      state
      |> Map.put(:state, :handled)
      |> Map.put(:contract_state, state.contract_module.handle_event(:handled, state.contract_state))
    {state}
  end

  def handle_message({[_,"watching"], _message}, state) do
    {Map.put(state, :contract_state, state.contract_module.handle_event(:watching, state.contract_state))}
  end

  def handle_message({[_,"notWatching"], _message}, state) do
    {Map.put(state, :contract_state, state.contract_module.handle_event(:not_watching, state.contract_state))}
  end

  def handle_message({[_,"event"], %{"event" => event}}, state) do
    {Map.put(state, :contract_state, state.contract_module.handle_event({:event, event}, state.contract_state))}
  end

  def handle_message(message, state) do
    Logger.debug "#{inspect self}:#{__MODULE__} ignoring message: #{inspect message} with current state #{inspect state}"
    {state}
  end

  defp unique_name do
    :erlang.unique_integer |> Integer.to_string |> String.replace("-", "N")
  end

  def handle_call({:begin_watching}, _from, state) do
    {:actions, [:begin_watching], :reply, :ok, state}
  end
end