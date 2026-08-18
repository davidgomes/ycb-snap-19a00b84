defmodule BadgeForge.PrintCenterTest do
  use BadgeForge.DataCase, async: true
  use Oban.Testing, repo: BadgeForge.Repo

  alias BadgeForge.PrintCenter

  test "perform/1 processes printing job" do
    assert :ok =
             perform_job(PrintCenter, %{
               "id" => Ecto.UUID.generate(),
               "name" => "Ada Lovelace",
               "path" => "tmp/badges/ada.pdf"
             })
  end
end
