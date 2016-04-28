defmodule Exdistex.IntegrationTest do
  use ExUnit.Case

  defmodule TestConsumerContract do
    def handle_event(event, test_pid) do
      send test_pid, event
      test_pid
    end
  end

  test "Can establish arrangement from a consumer contract to a producer" do
    test_pid = self()

    {:ok, provider} = Exdistex.SimpleProvider.start_link
    {:ok, consumer} = Exdistex.GenConsumerContract.start_link(%{"ping" => "once"}, TestConsumerContract, test_pid)

    assert_receive :handled
  end
end