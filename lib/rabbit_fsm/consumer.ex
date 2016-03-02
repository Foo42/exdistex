defmodule Exdistex.ConsumerRFSM do
  require Logger
  def start_link(expression) do
    Exdistex.GenRabbitFSM.start_link(__MODULE__, %{expression: expression})
  end

  def handle_start(%{expression: expression} = state) do
    request_id = unique_name
    actions = [subscribe: "event.handler.available", publish: {"event.handler.required", %{"expression" => expression, "requestId" => request_id}}]
    state = state
      |> Map.put(:request_id, request_id)
      |> Map.put(:state, :requested)
    {actions, state}
  end

  def handle_start(state) do
    {state}
  end

  def handle_message({"event.handler.available", %{"requestId" => request_id} = message}, %{request_id: request_id} = state) do
    %{"handlingToken" => handler} = message
    state = state
      |> Map.put(:hander, handler)
      |> Map.put(:state, :accepting)

    actions = [
      subscribe: "#{handler}.#",
      publish: {"#{handler}.accept",%{
        "handlingToken" => handler,
        "expression" => state.expression
      }}
    ]
    {actions, state}
  end

  def handle_message({message_key, %{"requestId" => request_id} = message}, state) when is_binary(message_key) do
    handle_message({String.split(message_key, "."), message}, state)
  end
  def handle_message({[_,"handling"],message}, %{state: :accepting} = state) do
    {Map.put(state, :state, :handled)}
  end
  def handle_message(message, state) do
    Logger.debug "#{inspect self} ignoring message: #{inspect message} with current state #{inspect state}"
    {state}
  end


  defp unique_name do
    :erlang.unique_integer |> Integer.to_string |> String.replace("-", "N")
  end
end