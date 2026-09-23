defmodule ObanChore.ConnCase do
  @moduledoc """
  Test case for LiveView tests against the dashboard mounted by `ObanChore.TestRouter`.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      use Oban.Testing, repo: ObanChore.TestRepo

      import ObanChore.DataCase
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest

      @endpoint ObanChore.TestEndpoint
    end
  end

  setup tags do
    ObanChore.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
