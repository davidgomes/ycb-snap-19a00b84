defmodule ObanEvents.TestingTest do
  use ExUnit.Case, async: true

  alias ObanEvents.Testing

  # These helpers rely on `Oban.Testing.assert_enqueued/2`, which queries the
  # database for enqueued jobs. `ObanEvents.Test.Repo` (used across this
  # library's own test suite) runs Oban in `:inline` mode, which never
  # touches the database, so full integration coverage of
  # `assert_event_emitted/4` and `refute_event_emitted/4` belongs in a
  # consuming application configured for `:manual` testing mode (see the
  # README). Here we cover the pure argument-building helper instead.

  describe "build_event_args/4" do
    test "builds args with the event name and handler as fully-qualified strings" do
      args = Testing.build_event_args(:user_created, ObanEvents.EventTest)

      assert args["event"] == "user_created"
      assert args["handler"] == "Elixir.ObanEvents.EventTest"
    end

    test "defaults data and metadata to empty maps" do
      args = Testing.build_event_args(:user_created, ObanEvents.EventTest)

      assert args["data"] == %{}
      assert args["metadata"] == %{}
    end

    test "includes the given data and metadata" do
      args =
        Testing.build_event_args(
          :user_created,
          ObanEvents.EventTest,
          %{"user_id" => 1},
          %{"source" => "signup_form"}
        )

      assert args["data"] == %{"user_id" => 1}
      assert args["metadata"] == %{"source" => "signup_form"}
    end
  end
end
