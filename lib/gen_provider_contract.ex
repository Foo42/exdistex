defmodule Exdistex.GenProviderContract do
	def start_link(delegate_module, initial_request) do
		IO.puts "in gen GenProviderContract with #{inspect delegate_module} #{inspect initial_request}"
	end
end
