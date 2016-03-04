defmodule Exdistex.LambdaContract do
  require Logger
  def handle_event(event, {lambda, state}) do
    {:ok, {lambda, lambda.(event, state)}}
  end
end