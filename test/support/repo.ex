defmodule ObanChore.Test.Repo do
  use Ecto.Repo, otp_app: :oban_chore, adapter: Ecto.Adapters.Postgres
end

defmodule ObanChore.Test.Migration do
  use Ecto.Migration

  def up, do: Oban.Migration.up()
  def down, do: Oban.Migration.down()
end
