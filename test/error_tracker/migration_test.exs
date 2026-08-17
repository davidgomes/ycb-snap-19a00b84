defmodule ErrorTracker.MigrationTest do
  use ErrorTracker.Test.Case

  alias ErrorTracker.Migration

  test "migration current_version works" do
    assert Migration.current_version(repo: repo()) == 5
  end
end
