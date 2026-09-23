defmodule NewsletterWeb.SubscriberController do
  use NewsletterWeb, :controller

  alias Newsletter.Subscribers

  def create(conn, %{"subscriber" => subscriber_params}) do
    case Subscribers.create_subscriber(subscriber_params) do
      {:ok, subscriber} ->
        # Welcome the user when they sign up.
        Newsletter.Emails.welcome(subscriber)
        |> Newsletter.Mailer.deliver()

        conn
        |> put_flash(:info, "Subscriber created successfully.")
        |> redirect(to: Routes.page_path(conn, :index))

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_view(NewsletterWeb.PageView)
        |> render("index.html", changeset: changeset)
    end
  end
end
