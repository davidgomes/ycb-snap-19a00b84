defmodule BadgeForge.BadgeForgeTest do
  use BadgeForge.DataCase, async: true
  use Oban.Testing, repo: BadgeForge.Repo

  test "enqueue_batch/1 enqueues jobs to :badges queue for Python worker" do
    assert {:ok, jobs} = BadgeForge.enqueue_batch(5)
    assert length(jobs) == 5

    assert_enqueued(
      worker: "badge_forge.generator.GenerateBadge",
      queue: :badges
    )

    for job <- jobs do
      assert job.worker == "badge_forge.generator.GenerateBadge"
      assert job.queue == "badges"
      assert is_binary(job.args["id"])
      assert is_binary(job.args["name"])
      assert is_binary(job.args["company"])
      assert job.args["type"] in ~w(attendee speaker sponsor organizer)
    end
  end
end
