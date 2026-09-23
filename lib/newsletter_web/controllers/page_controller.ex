defmodule NewsletterWeb.PageController do
  use NewsletterWeb, :controller

  alias Newsletter.Subscribers
  alias Newsletter.Subscribers.Subscriber

  def index(conn, _params) do
    render(conn, "index.html", changeset: Subscribers.change_subscriber(%Subscriber{}))
  end
end
