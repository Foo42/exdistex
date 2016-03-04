defmodule Excercise do
  def run do
    {:ok, provider} = Exdistex.SimpleProvider.start_link
    {:ok, consumer} = Exdistex.LoggingContract.start_link %{"hello" => "world"}
  end
end