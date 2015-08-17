defmodule Exdistex.ProviderLogger do
	def ping(payload), do: IO.puts "GOT: #{payload}"
end
