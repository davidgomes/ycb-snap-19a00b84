defmodule GenQueue.Oban.Repo do
  @moduledoc false

  use Ecto.Repo,
    otp_app: :gen_queue_oban,
    adapter: Ecto.Adapters.Postgres
end
