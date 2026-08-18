defmodule BadgeForgeTest do
  use BadgeForge.DataCase, async: true
  use Oban.Testing, repo: BadgeForge.Repo

  describe "enqueue_batch/1" do
    test "inserts jobs for the Python GenerateBadge worker" do
      assert :ok = BadgeForge.enqueue_batch(3)

      jobs = all_enqueued(worker: "badge_forge.workers.GenerateBadge", queue: :badges)

      assert length(jobs) == 3

      Enum.each(jobs, fn job ->
        assert job.worker == "badge_forge.workers.GenerateBadge"
        assert job.queue == "badges"
        assert is_binary(job.args["id"])
        assert is_binary(job.args["name"])
        assert is_binary(job.args["company"])
        assert job.args["type"] in ~w(attendee speaker sponsor organizer)
      end)
    end
  end
end
