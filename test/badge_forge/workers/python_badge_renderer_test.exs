defmodule BadgeForge.Workers.PythonBadgeRendererTest do
  use BadgeForge.DataCase, async: true
  use Oban.Testing, repo: BadgeForge.Repo

  alias BadgeForge.Badges
  alias BadgeForge.Workers.PythonBadgeRenderer

  test "enqueue_render/2 inserts a job with the given args" do
    assert {:ok, job} = Badges.enqueue_render("build", "passing")

    assert_enqueued worker: PythonBadgeRenderer, args: %{"label" => "build", "value" => "passing"}
    assert job.args == %{"label" => "build", "value" => "passing"}
  end

  test "perform/1 renders an SVG badge by invoking the Python script" do
    job = %Oban.Job{args: %{"label" => "build", "value" => "passing"}}

    assert {:ok, svg} = perform_job(PythonBadgeRenderer, job.args)
    assert svg =~ "<svg"
    assert svg =~ "build"
    assert svg =~ "passing"
  end
end
