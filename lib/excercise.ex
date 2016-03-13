defmodule Excercise do
  def run do
    {:ok, provider} = Exdistex.SimpleProvider.start_link
    {:ok, consumer} = Exdistex.LoggingConsumerContract.start_link %{"hello" => "world"}
  end
end