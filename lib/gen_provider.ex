defmodule Exdistex.GenProvider do
  defmacro __using__(_) do
    quote do
      @behaviour Exdistex.Provider
      def init(state), do: state
      def event_handler_required(message, state), do: state

      defoverridable [init: 1, event_handler_required: 2]
    end
  end

  def start_link(provider_mod, provider_state \\ %{}, options \\ []) do
    Exdistex.GenRabbitFSM.start_link(__MODULE__, %{provider_mod: provider_mod, provider_state: provider_state}, options)
  end

  def handle_start(%{provider_mod: provider_mod, provider_state: provider_state} = state) do
    initialised_provider_state = provider_mod.init(provider_state)
    {:actions, [subscribe: "event.handler.required"], %{state | provider_state: initialised_provider_state}}
  end

  def handle_message({"event.handler.required", message}, state) do
    provider_state = state.provider_mod.event_handler_required message, state.provider_state
    {%{state | provider_state: provider_state}}
  end
end

defmodule Exdistex.Provider do
  @callback init(any) :: any
  @callback event_handler_required(any, any) :: any
end