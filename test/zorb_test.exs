defmodule ZorbTest do
  use ExUnit.Case
  doctest Zorb

  test "greets the world" do
    assert Zorb.hello() == :world
  end
end
