defmodule Exdistex.GenProviderContract do
	defmacro __using__(_) do
		quote location: :keep do
			use GenServer
		    alias AMQP.Basic

			def start_link(initial_request, amqp_channel) do
				GenServer.start_link(__MODULE__, %{initial_request: initial_request, amqp_channel: amqp_channel})
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
		        AMQP.Basic.publish chan, "distex", "event.handler.available", "#{Poison.Encoder.encode(message, [])}"

		        new_state = state 
		        	|> Dict.put(:token, token)
		        	|> Dict.put(:accepted, false)
		        	|> Dict.put(:spec, initial_request)
		        	|> Dict.put(:request_id, request_id)

		        {:ok, new_state}
			end

			defp send_contract_message(state = %{amqp_channel: chan, token: token}, message_type, body) do
		        AMQP.Basic.publish chan, "distex", "#{token}.#{message_type}", "#{Poison.Encoder.encode(body, [])}"
			end

			defp raise_contract_event(event, contract \\ self()) do
				send contract, {:raise_contract_event, event}
			end

			defp process_message("accept", message, state = %{accepted: false}) do
				send_contract_message state, "handling", standard_message_body(state)
				state 
					|> Dict.put(:accepted, true)
					|> Dict.put(:watching, false)
					|> Dict.put(:delegate_state, on_handling(state[:spec]))
			end

			defp process_message("watch", message, state = %{watching: false, accepted: true}) do
				new_delegate_state = on_watch(state[:spec], state[:delegate_state])
				send_contract_message state, "watching", standard_message_body(state)
				state
					|> Dict.put(:watching, true)
					|> Dict.put(:delegate_state, new_delegate_state)
			end

			defp process_message("stopWatching", message, state = %{watching: true, accepted: true}) do
				new_delegate_state = on_stop_watch(state[:spec], state[:delegate_state])
				send_contract_message state, "notWatching", %{"requestId" => state[:request_id], "handlingToken" => state[:token]}
				state
					|> Dict.put(:watching, false)
					|> Dict.put(:delegate_state, new_delegate_state)
			end

			defp process_message(message_type, message, state) do
				state
			end

			defp standard_message_body(state) do
				%{"requestId" => state[:request_id], "handlingToken" => state[:token]}
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
		        {:noreply, process_message(extract_message_type(routing_key), Poison.decode!(payload), state)}
		    end

		    def handle_info({:raise_contract_event, event}, state) do
		    	message = standard_message_body(state) |> Dict.put("event", event) 
				send_contract_message(state, "event", message)
		    	{:noreply, state}
		    end

		    defp extract_message_type(routing_key)do
		    	String.replace(routing_key, ~r/[^\.]+\./, "")
		    end

		    def on_handling(_spec) do
		    	%{}
		    end

		    def on_watch(_spec, state) do
		    	state
		    end

		    def on_stop_watch(_spec, state) do
		    	state
		    end

		    defoverridable [on_handling: 1, on_watch: 2, on_stop_watch: 2]
		end
	end
end
