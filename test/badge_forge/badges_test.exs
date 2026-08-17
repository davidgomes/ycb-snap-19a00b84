defmodule BadgeForge.BadgesTest do
  use BadgeForge.DataCase, async: true
  use Oban.Testing, repo: BadgeForge.Repo

  alias BadgeForge.Badges

  describe "enqueue/1" do
    test "inserts a job targeting the Python badge generation worker" do
      attrs = %{id: "badge-1", name: "Ada Lovelace", company: "Soren", type: "speaker"}

      assert {:ok, job} = Badges.enqueue(attrs)

      assert job.worker == "badge_forge.generator.GenerateBadge"
      assert job.queue == "badges"
      assert job.args == %{
               "id" => "badge-1",
               "name" => "Ada Lovelace",
               "company" => "Soren",
               "type" => "speaker"
             }

      assert_enqueued(
        worker: "badge_forge.generator.GenerateBadge",
        queue: :badges,
        args: attrs
      )
    end

    test "generates an id when one isn't provided" do
      attrs = %{name: "Grace Hopper", company: "Navy", type: "sponsor"}

      assert {:ok, job} = Badges.enqueue(attrs)

      assert is_binary(job.args["id"])
    end
  end

  describe "enqueue_batch/1" do
    test "inserts a job per attendee for the Python worker" do
      attrs_list = [
        %{name: "Ada Lovelace", company: "Soren", type: "speaker"},
        %{name: "Alan Turing", company: "Bletchley", type: "attendee"}
      ]

      jobs = Badges.enqueue_batch(attrs_list)

      assert length(jobs) == 2
      assert Enum.all?(jobs, &(&1.worker == "badge_forge.generator.GenerateBadge"))
      assert Enum.all?(jobs, &(&1.queue == "badges"))
    end
  end
end
