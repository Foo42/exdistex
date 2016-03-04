defmodule Excercise do
  def run do
    {:ok, provider} = Exdistex.SimpleProvider.start_link


    # {:ok, provider} = Exdistex.ProviderRFSM.start_link
    {:ok, consumer} = Exdistex.ConsumerRFSM.start_link %{"hello" => "world"}, Exdistex.LoggingContract
  end
end