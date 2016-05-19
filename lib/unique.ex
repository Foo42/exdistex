defmodule Exdistex.Unique do
  def string do
    :rand.uniform |> Float.to_string() |> String.replace(".", "") |> String.replace("e", "") |> String.replace("-", "")
  end
end