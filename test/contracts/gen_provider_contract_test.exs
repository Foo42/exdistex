defmodule Exdistex.GenProducerContractTest do
  alias Exdistex.GenProviderContract
  use ExUnit.Case

  defmodule TestContract do
    use Exdistex.GenProviderContract

    def handle_event(:init, %{options: options} = state) do
      case Keyword.get(options, :target) do
        nil -> nil
        target -> send target, {:init, state}
      end
      {:ok, Enum.into(options, %{})}
    end
    def handle_event(event, %{target: target} = state) do
      send target, {event, state}
      {:ok, state}
    end
    def handle_event(event, state), do: {:ok, state}
    def handle_call(message, _from, state) do
      reply = {:recieved, message, state}
      new_state = :updated
      {:reply, reply, new_state}
    end
  end

  test "handle_call delegates and mixes returned state back in" do
    outer_state = %{contract_state: :original_contract_state, contract_module: TestContract}
    {:reply, reply, %{contract_state: final_contract_state}} = GenProviderContract.handle_call(:some_message, :someone, outer_state)
    assert reply == {:recieved, :some_message, :original_contract_state}
    assert final_contract_state == :updated
  end

  test "initial contract state passed through to delegate with init include message, expression and options" do
    request = %{"requestId" => 42, "expression" => "xmas alert"}
    options = [something: "stuff", target: self()]
    contract = GenProviderContract.start_link(TestContract, request, options)
    assert_receive {:init, %{expression: "xmas alert", request: requests, options: options}}
  end
end