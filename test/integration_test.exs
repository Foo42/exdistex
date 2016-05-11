defmodule Exdistex.IntegrationTest do
  use ExUnit.Case
  require Logger

  defmodule TestConsumerContract do
    def handle_event(event, test_pid) do
      Logger.debug "#{__MODULE__} recieved contract event: #{inspect event}"
      send test_pid, event
      test_pid
    end
  end

  @tag only: true
  @tag integration: true
  test "Can establish arrangement from a consumer contract to a producer" do
    test_pid = self()

    {:ok, provider} = Exdistex.SimpleProvider.start_link
    {:ok, consumer} = Exdistex.GenConsumerContract.start_link(%{"ping" => "once"}, TestConsumerContract, test_pid)


    assert_receive :handled
    Exdistex.GenConsumerContract.begin_watching(consumer)
    assert_receive {:event, "ping!"}
  end
end