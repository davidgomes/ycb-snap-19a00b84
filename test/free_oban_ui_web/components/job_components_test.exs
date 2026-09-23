defmodule FreeObanUiWeb.JobComponentsTest do
  use ExUnit.Case, async: true

  import FreeObanUiWeb.JobComponents

  @now ~U[2024-09-01 12:00:00Z]

  test "format_relative/2" do
    assert format_relative(@now, @now) == "now"
    assert format_relative(DateTime.add(@now, -42, :second), @now) == "42s ago"
    assert format_relative(DateTime.add(@now, -5, :minute), @now) == "5m ago"
    assert format_relative(DateTime.add(@now, 3, :hour), @now) == "in 3h"
    assert format_relative(DateTime.add(@now, -2, :day), @now) == "2d ago"
  end
end
