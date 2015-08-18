defmodule Exdistex.GenProviderContract do
	use GenServer
    alias AMQP.Basic

	def start_link(delegate_module, initial_request, amqp_channel) do
		GenServer.start_link(__MODULE__, %{initial_request: initial_request, amqp_channel: amqp_channel, module: delegate_module})
	end

	def init(state = %{amqp_channel: chan, initial_request: initial_request}) do
        token = "#{:random.uniform}" |> String.replace ".", ""
        queue_name = "contract-" <> token
        {:ok, queue} = AMQP.Queue.declare(chan, queue_name, durable: false, exclusive: true)
        :ok = AMQP.Queue.bind chan, queue_name, "distex", routing_key: token <> ".#"
        {:ok, _consumer_tag} = AMQP.Basic.consume(chan, queue_name)

        request_id = initial_request["id"]
        message = %{
            "handlingToken" => token,
            "requestId" => request_id
        }
        :timer.sleep(1000)
        IO.puts "publishing message #{Poison.Encoder.encode(message, [])}"
        # send_contract_message chan, "event.handler.available", message
        AMQP.Basic.publish chan, "distex", "event.handler.available", "#{Poison.Encoder.encode(message, [])}"

        new_state = state |> Dict.put(:token, token) |> Dict.put(:status, "offered") |> Dict.put(:request_id, request_id)
        {:ok, new_state}
	end

	defp send_contract_message(state = %{amqp_channel: chan, token: token}, message_type, body) do
        IO.puts "publishing message #{token}.#{message_type} with body #{Poison.Encoder.encode(body, [])}"
        AMQP.Basic.publish chan, "distex", "#{token}.#{message_type}", "#{Poison.Encoder.encode(body, [])}"
	end

	defp process_message("accept", message, state) do
		IO.puts "Recieved accept message on contract topic #{inspect message}"
		send_contract_message state, "handling", %{"requestId" => state[:request_id], "handlingToken" => state[:token]}
		state
	end

	defp process_message(message_type, message, state) do
		IO.puts "Recieved message of type #{message_type} on contract topic #{inspect message}"
		state
	end

	# Confirmation sent by the broker after registering this process as a consumer
    def handle_info({:basic_consume_ok, %{consumer_tag: consumer_tag}}, state) do
        {:noreply, state}
    end

    # Sent by the broker when the consumer is unexpectedly cancelled (such as after a queue deletion)
    def handle_info({:basic_cancel, %{consumer_tag: consumer_tag}}, state) do
        {:stop, :normal, state}
    end

    # Confirmation sent by the broker to the consumer process after a Basic.cancel
    def handle_info({:basic_cancel_ok, %{consumer_tag: consumer_tag}}, state) do
        {:noreply, state}
    end

    def handle_info({:basic_deliver, payload, %{routing_key: routing_key}}, state) do
    	IO.puts "routing_key = #{routing_key}"
    	IO.puts "message_type = #{extract_message_type(routing_key)}"
        {:noreply, process_message(extract_message_type(routing_key), Poison.decode!(payload), state)}
    end

    defp extract_message_type(routing_key)do
    	String.replace(routing_key, ~r/[^\.]+\./, "")
    end
end
