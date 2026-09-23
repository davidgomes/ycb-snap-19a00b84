defmodule ObanChore.Test.Endpoint do
  use Phoenix.Endpoint, otp_app: :oban_chore

  @session_options [store: :cookie, key: "_oban_chore_key", signing_salt: "oban_chore"]

  socket("/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]])

  plug(Plug.Session, @session_options)
  plug(ObanChore.Test.Router)
end
