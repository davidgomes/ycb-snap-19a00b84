defmodule NewsletterWeb.SubscriberController do
  use NewsletterWeb, :controller

  alias Newsletter.Subscribers
  alias Newsletter.Subscribers.Subscriber

  def new(conn, _params) do
    changeset = Subscribers.change_subscriber(%Subscriber{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"subscriber" => subscriber_params}) do
    case Subscribers.create_subscriber(subscriber_params) do
      {:ok, _subscriber} ->
        conn
        |> put_flash(:info, "Subscribed! Check your inbox for a welcome email.")
        |> redirect(to: Routes.page_path(conn, :index))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end
end
