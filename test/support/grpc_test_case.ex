defmodule Warehouse.GRPCTestCase do
  @moduledoc """
  Sets up a channel to the gRPC server started by the application, so tests can
  talk to it with the `Bottle` stubs.

  Requests are handled in the server's own process, so the database connection
  is shared instead of being checked out by the test process alone.
  """

  use ExUnit.CaseTemplate

  @port 50_051

  using do
    quote do
      alias Warehouse.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Warehouse.Factory
    end
  end

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Warehouse.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Warehouse.Repo, {:shared, self()})

    {:ok, channel} = GRPC.Stub.connect("localhost:#{@port}")

    on_exit(fn -> GRPC.Stub.disconnect(channel) end)

    {:ok, channel: channel}
  end
end
