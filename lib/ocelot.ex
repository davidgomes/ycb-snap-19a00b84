defmodule Ocelot do
  @moduledoc """
  A lightweight Oban dashboard served as a plain `Plug`, no Phoenix required.

  Mount it inside any `Plug.Router`:

      forward "/oban", to: Ocelot

  ## Options

    * `:oban` - the name of the running Oban instance to inspect. Defaults to `Oban`.
  """

  @behaviour Plug

  import Plug.Conn

  @impl true
  def init(opts) do
    Keyword.get(opts, :oban, Oban)
  end

  # Oban's config is resolved per request because `init/1` may run at compile
  # time, before any Oban instance is started.
  @impl true
  def call(conn, oban_name) do
    conn
    |> put_private(:ocelot, %{conf: Oban.config(oban_name), base: base_path(conn)})
    |> Ocelot.Router.call(Ocelot.Router.init([]))
  end

  defp base_path(%Plug.Conn{script_name: []}), do: ""
  defp base_path(%Plug.Conn{script_name: parts}), do: "/" <> Enum.join(parts, "/")
end
