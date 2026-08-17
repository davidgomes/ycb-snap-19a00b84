defmodule ErrorTracker.ErrorTest do
  use ErrorTracker.Test.Case

  alias ErrorTracker.Error
  alias ErrorTracker.Stacktrace

  describe inspect(&Error.new/3) do
    test "sets default values" do
      {:ok, stacktrace} = Stacktrace.new([])
      {:ok, error} = Error.new("RuntimeError", "Something went wrong", stacktrace)

      assert error.status == :unresolved
      refute error.muted
    end
  end
end
