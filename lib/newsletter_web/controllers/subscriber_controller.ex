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
      {:ok, subscriber} ->
        # Welcome the user when they sign up.
        Newsletter.Emails.welcome(subscriber)
        |> Newsletter.Mailer.deliver()

        conn
        |> put_flash(:info, "Subscriber created successfully.")
        |> redirect(to: Routes.subscriber_path(conn, :show, subscriber))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    subscriber = Subscribers.get_subscriber!(id)
    render(conn, "show.html", subscriber: subscriber)
  end
end
