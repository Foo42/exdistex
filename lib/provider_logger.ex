defmodule Exdistex.ProviderLogger do
	def ping(payload), do: IO.puts "GOT: #{payload}"
	def handle?(request,state) do
		IO.puts "ProviderLogger recieved request #{inspect request}"
		{true, Exdistex.LoggerContract, state}
	end
end
