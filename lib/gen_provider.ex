defmodule Exdistex.GenProvider do
    use GenServer
    alias AMQP.Basic

    def start_link(delegateModule) do
        GenServer.start_link(__MODULE__, delegateModule)
    end

    def init(delegateModule, delegate_state \\ %{}) do
        {:ok, conn} = AMQP.Connection.open("amqp://admin:admin@localdocker")
        {:ok, chan} = AMQP.Channel.open(conn)
        queueName = "#{:random.uniform}"
        {:ok, queue} = AMQP.Queue.declare(chan, queueName, durable: false, exclusive: true)
        :ok = AMQP.Exchange.topic chan, "distex", durable: false, auto_delete: true
        :ok = AMQP.Queue.bind chan, queueName, "distex", routing_key: "event.handler.required"

        # AMQP.Queue.subscribe chan, queueName, fn(payload, _meta) -> IO.puts("Received: #{payload}") end
        {:ok, _consumer_tag} = AMQP.Basic.consume(chan, queueName)

        {:ok, %{chan: chan, module: delegateModule, delegate_state: delegate_state}}
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

    def handle_info({:basic_deliver, payload, %{delivery_tag: tag, redelivered: redelivered}}, state =%{chan: chan, module: delegateModule, delegate_state: delegate_state}) do
        delegate_response = delegateModule.handle?(payload,delegate_state)
        IO.puts "delegateModule replied with #{inspect delegate_response}"

        case  delegate_response do
            {true, contract_module, new_delegate_state} ->
                create_contract(payload, contract_module, chan)
                {:noreply, %{state | delegate_state: new_delegate_state}}
            {false, new_delegate_state} -> 
                {:noreply, %{state | delegate_state: new_delegate_state}}
        end
    end

    defp create_contract(initial_request, contract_module, amqp_channel) do
        spawn_link fn -> Exdistex.GenProviderContract.start_link(contract_module, Poison.decode!(initial_request), amqp_channel) end #Need to think about enabling supervision of contracts
    end

    defp consume(channel, tag, redelivered, payload) do
        IO.puts "recieved #{payload}"
        # try do
        #   number = String.to_integer(payload)
        #   if number <= 10 do
        #     Basic.ack channel, tag
        #     IO.puts "Consumed a #{number}."
        #   else
        #     Basic.reject channel, tag, requeue: false
        #     IO.puts "#{number} is too big and was rejected."
        #   end
        # rescue
        #   exception ->
        #     # Requeue unless it's a redelivered message.
        #     # This means we will retry consuming a message once in case of exception
        #     # before we give up and have it moved to the error queue
        #     Basic.reject channel, tag, requeue: not redelivered
        #     IO.puts "Error converting #{payload} to integer"
        # end
    end

    def connect do
        {:ok, conn} = AMQP.Connection.open("amqp://admin:admin@localdocker")
        {:ok, chan} = AMQP.Channel.open(conn)
        queueName = "#{:random.uniform}"
        {:ok, queue} = AMQP.Queue.declare(chan, queueName, durable: false, exclusive: true)
        :ok = AMQP.Exchange.topic chan, "distex", durable: false, auto_delete: true
        :ok = AMQP.Queue.bind chan, queueName, "distex", routing_key: "event.handler.required"

        AMQP.Queue.subscribe chan, queueName, fn(payload, _meta) -> IO.puts("Received: #{payload}") end

        :ok
    end
end
