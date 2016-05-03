defmodule Exdistex.GenProviderTest do
  use ExUnit.Case
  alias Exdistex.GenProvider

  defmodule TestProvider do
    def init(test) do
      send test, :init
      test
    end

    def handle_event(event, test) do
      send test, {:event, event}
      {:ok, test}
    end
  end

  #Not sure whether this style of test is adding much value. Assertion isn't covering much logic.
  #Maybe focus on higher level tests, maybe requiring rabbit? We will need some coverage at that level
  #So may as well start with those tests and drill in for low level as required.
  test "on start delegates to given module then subscribes to event.handler.required messages" do
    state = %{provider_mod: TestProvider, provider_state: self}
    {:actions, actions, _state} = GenProvider.handle_start(state)
    assert_receive :init
    assert actions == [subscribe: "event.handler.required"]
  end
end