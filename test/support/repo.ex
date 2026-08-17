defmodule ObanDoctor.Test.Repo do
  use Ecto.Repo,
    otp_app: :oban_doctor,
    adapter: Ecto.Adapters.Postgres
end
