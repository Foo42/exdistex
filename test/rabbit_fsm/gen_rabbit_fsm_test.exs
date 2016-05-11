defmodule Exdistex.GenRabbitFSMTest do
  alias Exdistex.GenRabbitFSM
  use ExUnit.Case

  defmodule Tester do
    def handle_start(state) do
      send state.test, :connected
      {:actions, [subscribe: state.subscribe_to], state}
    end

    def handle_message(msg, state) do
      IO.puts inspect msg
      send state.test, "got_it"
      {state}
    end

    def handle_call({:set_state, new_state}, _from, state) do
      {:reply, {:was, state}, new_state}
    end
  end

  test "process delegate response passes regular OTP responses through mixing returned delegate state into given state" do
    total_state = %{delegate_state: :old, other: :stuff}
    response_from_delegate = {:noreply, :this_is_delegate_state}
    after_processing = GenRabbitFSM.process_delegate_response(response_from_delegate, total_state)
    assert after_processing == {:noreply, %{delegate_state: :this_is_delegate_state, other: :stuff}}
  end

  test "process delegate response removes actions from response" do
    total_state = %{delegate_state: :old, other: :stuff}
    response_from_delegate = {:actions, [], :noreply, :this_is_delegate_state}
    after_processing = GenRabbitFSM.process_delegate_response(response_from_delegate, total_state)
    assert after_processing == {:noreply, %{delegate_state: :this_is_delegate_state, other: :stuff}}
  end

  @tag only: true
  test "process delegate response performs returned actions delegating unknown actions" do
    delegate_state = %{test_pid: self()}
    total_state = %{delegate_state: delegate_state, delegate_mod: TestDelegate, other: :stuff}
    response_from_delegate = {:actions, [{:funky_action}], :noreply, delegate_state}
    receive do
      {:recieved_action, {:funky_action}} -> :ok
    end
    GenRabbitFSM.process_delegate_response(response_from_delegate, total_state)
  end

  test "can start without errors" do
    {:ok, fsm} = GenRabbitFSM.start_link(Tester, %{test: self(), subscribe_to: "foo.bar"})
  end

  def send_to_rabbit(topic, message) do
    {:ok, conn} = AMQP.Connection.open("amqp://admin:admin@localdocker")
    {:ok, chan} = AMQP.Channel.open(conn)
    AMQP.Basic.publish chan, "distex", topic, message
  end

  @tag only: true
  test "delegate module is passed messages from rabbit" do
    {:ok, fsm} = GenRabbitFSM.start_link(Tester, %{test: self(), subscribe_to: "foo.bar"})
    assert_receive :connected
    send_to_rabbit "foo.bar", "hello from the test"
    assert_receive "got_it"
  end

  @tag only: true
  test "when called, passes messages onto delegates handle_call" do
    initial_state = %{test: self(), subscribe_to: "foo.bar"}
    {:ok, fsm} = GenRabbitFSM.start_link(Tester, initial_state)
    {:was, initial_state} = GenServer.call(fsm, {:set_state, :foo})
    {:was, :foo} = GenServer.call(fsm, {:set_state, :bar})
  end

end