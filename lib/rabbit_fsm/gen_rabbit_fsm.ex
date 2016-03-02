defmodule Exdistex.GenRabbitFSM do
    require Logger
    use GenServer
    alias AMQP.Basic

    def start_link(delegate_module, delegate_state \\ %{}) do
        GenServer.start_link(__MODULE__, %{delegate_mod: delegate_module, delegate_state: delegate_state})
    end

    def init(params) do
        {:ok, conn} = AMQP.Connection.open("amqp://admin:admin@localdocker")
        Logger.debug("#{inspect self} connection: #{inspect conn}")

        {:ok, chan} = AMQP.Channel.open(conn)
        Process.link chan.pid
        Logger.debug("#{inspect self} chan: #{inspect chan}")

        queue_name = unique_name
        {:ok, queue} = AMQP.Queue.declare(chan, queue_name, durable: false, exclusive: true)

        :ok = AMQP.Exchange.topic chan, "distex", durable: false, auto_delete: true
        {:ok, consumer_tag} = AMQP.Basic.consume(chan, queue_name)

        state =
          params
          |> Map.put(:consumer_tag, consumer_tag)
          |> Map.put(:channel, chan)
          |> Map.put(:queue_name, queue_name)
        {:ok, state}
    end

    def process_delegate_response({delegate_state}, all_state) do
      Logger.debug("#{inspect self} process_delegate_response: delegate_state: #{inspect delegate_state}, all state: #{inspect all_state}")
      res = %{all_state | delegate_state: delegate_state}
      Logger.debug("#{inspect self} full state after processing #{inspect res}")
      res
    end
      def process_delegate_response({actions, delegate_state}, all_state) do
      Logger.debug("#{inspect self} process_delegate_response: delegate_state: #{inspect delegate_state}, all state: #{inspect all_state}")
      res = %{perform_requests(actions,all_state) | delegate_state: delegate_state}
      Logger.debug("#{inspect self} full state after processing #{inspect res}")
      res
    end

    defp perform_requests([], state), do: state
    defp perform_requests(requests, state), do: Enum.reduce(requests, state, &perform_request/2)
    defp perform_request({:subscribe, topic}, state) do
      Logger.debug "#{inspect self} subscribing to #{topic}"
      %{channel: chan, queue_name: queue_name} = state
      :ok = AMQP.Queue.bind chan, queue_name, "distex", routing_key: topic
      state
    end
    defp perform_request({:publish, {topic, message}}, %{channel: chan} = state) do
      Logger.debug "#{inspect self} publishing to #{topic}"
      AMQP.Basic.publish chan, "distex", topic, Poison.encode!(message)
      state
    end
    defp perform_request(action, state) do
      Logger.debug "#{inspect self} Don't know how to perform #{inspect action}"
      state
    end

    # Confirmation sent by the broker after registering this process as a consumer
    def handle_info({:basic_consume_ok, %{consumer_tag: consumer_tag}}, %{delegate_mod: delegate_mod, delegate_state: delegate_state} = state) do
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

        new_state =
          {key, message}
          |> delegate_mod.handle_message(delegate_state)
          |> process_delegate_response(state)

        {:noreply, new_state}
    end

    defp unique_name do
      :erlang.unique_integer |> Integer.to_string |> String.replace "-", "N"
    end
end
