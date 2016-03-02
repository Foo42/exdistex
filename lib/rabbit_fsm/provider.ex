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

  def handle_start(state) do
    actions = [subscribe: "event.handler.required"]
    state = state
      |> Map.put(:state, :unassigned)

    {actions, state}
  end

  def handle_message({"event.handler.required", message}, state) do
    Logger.debug "#{inspect self} Noted that event handler is required, and accepting: #{inspect message}"

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

  def handle_message({message_key, %{"requestId" => request_id} = message}, state) when is_binary(message_key) do
    handle_message({String.split(message_key, "."), message}, state)
  end

  def handle_message({[handler, "accept"], message}, %{handling_token: handler} = state) do
      {[publish: Messages.handling(state)], Map.put(state, :state, :accepting)}
  end

  def handle_message(message, state) do
    Logger.debug "#{inspect self} ignoring message: #{inspect message}"
    {state}
  end

  defp unique_name do
    :erlang.unique_integer |> Integer.to_string |> String.replace("-", "N")
  end
end