defmodule Excercise do
  def run do
    {:ok, provider} = Exdistex.ProviderRFSM.start_link
    {:ok, consumer} = Exdistex.ConsumerRFSM.start_link %{"hello" => "world"}
  end
end