defmodule Exdistex.PingProviderContract do
  require Logger

  def start_link(message, options \\ []) do
    Exdistex.GenProviderContract.start_link __MODULE__, message, options
  end

  def handle_event(:init, expression) do
    {:ok, %{message: expression, pinger: nil}}
  end

  def handle_event(:watching, state) do
    Logger.debug "#{__MODULE__} is watching, starting to ping"
    {:ok, %{state | pinger: start_linked_pinger(state.pinger)}}
  end

  def handle_event(:accepted, state) do
    # {:raise_event, %{"ping" => 42}, state} TODO: We should be able to return actions to perform
    {:ok, state}
  end

  def handle_event(event, state) do
    Logger.info("#{__MODULE__}: event: #{inspect event}, state: #{inspect state}")
    {:ok, state}
  end

  def handle_call({:ping}, _from, state) do
    {:actions, [{:send_event, "ping!"}], :reply, :ok, state}
  end

  def start_linked_pinger(current_pinger) do
    case current_pinger do
      nil -> nil
      pid ->
        Process.unlink(pid)
        Process.exit(pid, :not_required)
    end

    target = self
    f = fn ->
      Stream.concat([0],Stream.interval(50))
        |> Stream.each(fn _ -> GenServer.call(target, {:ping}) end)
        |> Stream.run()
    end
    spawn_link(f)
  end
end