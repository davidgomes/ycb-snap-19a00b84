defmodule BadgeForge.BadgesTest do
  use BadgeForge.DataCase, async: true
  use Oban.Testing, repo: BadgeForge.Repo

  alias BadgeForge.Badges

  @generator "badge_forge.generator.GenerateBadge"

  describe "enqueue_badge/1" do
    test "inserting a job for the python generator" do
      attrs = %{name: "Ada Lovelace", company: "Analytical Engines", type: "speaker"}

      assert {:ok, job} = Badges.enqueue_badge(attrs)

      assert job.worker == @generator
      assert job.queue == "badges"
      assert job.args["name"] == "Ada Lovelace"
      assert job.args["company"] == "Analytical Engines"
      assert job.args["type"] == "speaker"
      assert is_binary(job.args["id"])

      assert_enqueued(worker: @generator, queue: :badges)
    end

    test "retaining an explicit id" do
      assert {:ok, job} = Badges.enqueue_badge(%{"id" => "abc-123", "name" => "Ada Lovelace"})

      assert job.args["id"] == "abc-123"
    end
  end

  describe "enqueue_badges/1" do
    test "inserting a job for each attendee" do
      assert [_, _] = jobs = Badges.enqueue_badges([%{name: "Ada"}, %{name: "Grace"}])

      assert Enum.all?(jobs, &(&1.worker == @generator))
      assert Enum.map(jobs, & &1.args["name"]) == ["Ada", "Grace"]
      assert jobs |> Enum.map(& &1.args["id"]) |> Enum.uniq() |> length() == 2
    end
  end
end
