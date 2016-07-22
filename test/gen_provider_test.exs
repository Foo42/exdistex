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


  defmodule EchoProviderContract do
    use Exdistex.GenProviderContract

    def start_link(tag) do
      target_pid = self()
      message = %{"expression" => %{}, "requestId" => tag}
      Exdistex.GenProviderContract.start_link(__MODULE__, message, [target: target_pid, tag: tag])
    end

    def handle_event(:init, %{options: options}) do
      IO.puts "options with init #{inspect options}"
      options_map = Enum.into(options, %{})
      IO.puts "options map #{inspect options_map}"
      {:ok, {options_map.target, options_map.tag}}
    end
    def handle_event(event, {target_pid, tag} = state) do
      IO.puts "received event: #{inspect event} with state #{inspect state}"
      send(target_pid, {tag, event})
      {:ok, state}
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

  @tag only: true
  test "options are passed through to delegate with init event" do
    leg_a = EchoProviderContract.start_link(:a)
  end
end