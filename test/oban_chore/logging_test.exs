defmodule ObanChore.LoggingTest do
  use ExUnit.Case, async: true

  test "log/2 broadcasts to the correct topic" do
    job = %Oban.Job{id: 123}
    topic = "oban_chore:logs:123"

    Phoenix.PubSub.subscribe(ObanChore.TestPubSub, topic)

    ObanChore.log(job, "Hello from the worker!")

    assert_receive {:oban_chore_log, 123, "Hello from the worker!"}
  end
end
