defmodule ObanChoreWeb.TestEndpoint do
  use Phoenix.Endpoint, otp_app: :oban_chore

  @session_options [
    store: :cookie,
    key: "_oban_chore_test_key",
    signing_salt: "oban_chore_test"
  ]

  socket("/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]])

  plug(Plug.Session, @session_options)
  plug(ObanChoreWeb.TestRouter)
end
