defmodule ExdistexTest do
  use ExUnit.Case

  test "the truth" do
    assert 1 + 1 == 2
  end

  test "doesnt pop" do
  	a = Exdistex.GenProvider.start_link(Exdistex.ProviderLogger)
  end
end
