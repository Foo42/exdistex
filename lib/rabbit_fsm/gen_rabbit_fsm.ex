  defmodule Exdistex.GenRabbitFSM do
    require Logger
    use GenServer
    alias AMQP.Basic

    def start_link(delegate_module, delegate_state \\ %{}, options \\ []) do
        state = %{delegate_mod: delegate_module, delegate_state: delegate_state, options: options}
        GenServer.start_link(__MODULE__, state)
    end

    def init(params) do
        {:ok, conn} = get_connection(params.options)

        {:ok, chan} = AMQP.Channel.open(conn)
        Process.link chan.pid

        queue_name = unique_name
        {:ok, queue} = AMQP.Queue.declare(chan, queue_name, durable: false, exclusive: true)

        :ok = AMQP.Exchange.topic chan, "distex", durable: false, auto_delete: true
        {:ok, consumer_tag} = AMQP.Basic.consume(chan, queue_name)
        :ok = receive do #Ensure we are consuming before we return from init
          {:basic_consume_ok, %{consumer_tag: consumer_tag}} -> :ok
        end

        params
          |> Map.put(:consumer_tag, consumer_tag)
          |> Map.put(:channel, chan)
          |> Map.put(:queue_name, queue_name)
          |> initialise_delegate()
    end

    defp initialise_delegate(state) do
      state.delegate_state
        |> state.delegate_mod.handle_start()
        |> process_delegate_response(state, :ok)
    end

    defp get_connection(options) do
      case Keyword.get(options, :connection) do
        nil -> AMQP.Connection.open("amqp://admin:admin@localdocker")
        connection -> connection
      end
    end

    def process_delegate_response(response, all_state, default_tuple_prefix \\ :noreply) when is_tuple(response) do
      response_parts = Tuple.to_list(response)
      state_after_actions = case response_parts do
        [:actions | [action_list | _tail]] ->
          perform_requests(action_list, all_state)
        _parts -> all_state
      end

      response_parts
        |> drop_actions()
        |> List.update_at(-1, &%{state_after_actions | delegate_state: &1})
        |> apply_default_prefix(default_tuple_prefix)
        |> List.to_tuple
    end

    defp apply_default_prefix([h|t] = parts_list, _) when is_atom(h), do: parts_list
    defp apply_default_prefix([h|t] = parts_list, prefix), do: [prefix | parts_list]

    defp drop_actions([:actions | [action_list | tail]]), do: tail
    defp drop_actions(parts), do: parts
    #todo: update callers, implementers now need to return different format tuple, and we need to consider whether
    # handle message implementations ought to need to add a :no_reply element as they cant actually "reply" as such

    defp perform_requests([], state), do: state
    defp perform_requests(requests, state), do: Enum.reduce(requests, state, &perform_request/2)
    defp perform_request({:subscribe, topic}, state) do
      Logger.debug "#{inspect self}:#{state.delegate_mod} subscribing to #{topic}"
      %{channel: chan, queue_name: queue_name} = state
      :ok = AMQP.Queue.bind chan, queue_name, "distex", routing_key: topic
      state
    end
    defp perform_request({:publish, {topic, message}}, %{channel: chan} = state) do
      Logger.debug "#{inspect self}:#{state.delegate_mod} publishing to #{topic}"
      AMQP.Basic.publish chan, "distex", topic, Poison.encode!(message)
      state
    end
    defp perform_request(action, state) do
      Logger.debug "#{inspect self}:#{state.delegate_mod} Don't know how to perform #{inspect action}"
      state
    end

    # Confirmation sent by the broker after registering this process as a consumer
    def handle_info({:basic_consume_ok, %{consumer_tag: consumer_tag}}, %{delegate_mod: delegate_mod, delegate_state: delegate_state} = state) do
      throw "should not hit this"
        new_state =
          delegate_state
          |> delegate_mod.handle_start
          |> process_delegate_response(state)
        {:noreply, new_state}
    end

    # Sent by the broker when the consumer is unexpectedly cancelled (such as after a queue deletion)
    def handle_info({:basic_cancel, %{consumer_tag: consumer_tag}}, state) do
        {:stop, :normal, state} #todo: let the delegate module decide if normal exit or not
    end

    # Confirmation sent by the broker to the consumer process after a Basic.cancel
    def handle_info({:basic_cancel_ok, %{consumer_tag: consumer_tag}}, state) do
        {:noreply, state}
    end

    def handle_info({:basic_deliver, payload, %{routing_key: key}}, %{delegate_mod: delegate_mod, delegate_state: delegate_state} = state) do
        message = case Poison.decode(payload) do
          {:ok, json} -> json
          _ -> payload
        end

        {key, message}
          |> delegate_mod.handle_message(delegate_state)
          |> process_delegate_response(state)
    end

    def handle_call(message, from, %{delegate_mod: delegate_mod, delegate_state: delegate_state} = state) do
      message
        |> delegate_mod.handle_call(from, delegate_state)
        |> process_delegate_response(state)
    end

    defp unique_name do
      :erlang.unique_integer() |> Integer.to_string() |> String.replace("-", "N")
    end
end
