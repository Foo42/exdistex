defmodule Exdistex.GenProducerContractTest do
  alias Exdistex.GenProviderContract
  use ExUnit.Case

  defmodule TestContract do
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
end