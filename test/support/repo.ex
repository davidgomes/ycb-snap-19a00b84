defmodule GenQueue.Oban.Test.Repo do
  use Ecto.Repo, otp_app: :gen_queue_oban, adapter: Ecto.Adapters.Postgres
end

defmodule GenQueue.Oban.Test.Migration do
  use Ecto.Migration

  def up, do: Oban.Migrations.up()
  def down, do: Oban.Migrations.down()
end
