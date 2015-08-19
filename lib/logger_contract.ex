defmodule Exdistex.LoggerContract do
	use Exdistex.GenProviderContract

	def on_handling(spec) do
		IO.puts "LoggerContract is handling: #{inspect spec}"
		%{}
	end

	def on_watch(_spec, state) do
		IO.puts "watching"
		state
	end

	def on_stop_watch(_spec, state) do
		IO.puts "stopped watching"
		state
	end
end
