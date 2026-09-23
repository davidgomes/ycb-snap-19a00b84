defmodule ObanChore.TestRepo do
  use Ecto.Repo, otp_app: :oban_chore, adapter: Ecto.Adapters.Postgres
end

defmodule ObanChore.TestRepo.Migration do
  use Ecto.Migration

  def up, do: Oban.Migrations.up()
  def down, do: Oban.Migrations.down(version: 1)
end
