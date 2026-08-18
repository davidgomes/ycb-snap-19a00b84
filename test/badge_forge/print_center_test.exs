defmodule BadgeForge.PrintCenterTest do
  use BadgeForge.DataCase, async: true
  use Oban.Testing, repo: BadgeForge.Repo

  test "handling a job enqueued by the python generator" do
    args = %{"id" => "abc-123", "name" => "Ada Lovelace", "path" => "/tmp/ada.html"}

    assert :ok = perform_job(BadgeForge.PrintCenter, args)
  end
end
