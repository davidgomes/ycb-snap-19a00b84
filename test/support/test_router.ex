defmodule ObanChore.Test.Router do
  use Phoenix.Router
  import Phoenix.LiveView.Router
  import ObanChore.Router

  pipeline :browser do
    plug(:fetch_session)
    plug(:fetch_live_flash)
  end

  scope "/" do
    pipe_through(:browser)

    oban_chore_dashboard("/chores")
  end
end
