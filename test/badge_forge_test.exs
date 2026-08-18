defmodule BadgeForgeTest do
  use BadgeForge.DataCase, async: true
  use Oban.Testing, repo: BadgeForge.Repo

  describe "enqueue_batch/1" do
    test "enqueues badge jobs for the Python worker" do
      assert :ok = BadgeForge.enqueue_batch(3)

      assert jobs = all_enqueued()
      assert length(jobs) == 3

      assert Enum.all?(jobs, fn job ->
               job.worker == "badge_forge.generator.GenerateBadge" and job.queue == "badges"
             end)
    end

    test "includes the badge data expected by Python" do
      assert :ok = BadgeForge.enqueue_batch(1)
      assert [%Oban.Job{args: args}] = all_enqueued()

      assert is_binary(args["id"])
      assert is_binary(args["name"])
      assert is_binary(args["company"])
      assert args["type"] in ~w(attendee speaker sponsor organizer)
    end

    test "does not enqueue anything for an empty batch" do
      assert :ok = BadgeForge.enqueue_batch(0)
      assert [] = all_enqueued()
    end
  end
end
