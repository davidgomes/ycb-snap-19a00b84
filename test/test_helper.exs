# Phoenix encodes JS commands with Jason by default, which isn't a dependency
# of this project. Elixir's built-in JSON module is enough to render them.
Application.put_env(:phoenix, :json_library, JSON)

ExUnit.start()
