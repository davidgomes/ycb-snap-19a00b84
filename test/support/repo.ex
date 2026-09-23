defmodule GenQueueOban.TestRepo do
  use Ecto.Repo, otp_app: :gen_queue_oban, adapter: Ecto.Adapters.Postgres
end
