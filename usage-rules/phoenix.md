## Phoenix guidelines

- Router `scope` blocks include an optional alias which is prefixed to all routes within the scope. You **never** need to create your own `alias` for route definitions, and you must avoid duplicating module prefixes:

      scope "/admin", AppWeb.Admin do
        pipe_through :browser

        live "/users", UserLive, :index
      end

  the `UserLive` route points to the `AppWeb.Admin.UserLive` module

- `Phoenix.View` is no longer needed or included with Phoenix, don't use it
