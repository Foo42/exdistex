defmodule Exdistex.LoggerContract do
	use Exdistex.GenProviderContract

	def on_handling(spec) do
		IO.puts "LoggerContract is handling: #{inspect spec}"
		%{}
	end

	def on_watch(_spec, state) do
		IO.puts "watching"
		contract = self()
		spawn_link fn -> 
			:timer.sleep(5000)
			raise_contract_event "boo", contract
		end
		state
	end

	def on_stop_watch(_spec, state) do
		IO.puts "stopped watching"
		state
	end
end
