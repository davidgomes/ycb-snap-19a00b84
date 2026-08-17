defmodule NewsletterWeb.SubscriptionController do
  use NewsletterWeb, :controller

  alias Newsletter.Subscribers

  def create(conn, %{"subscriber" => subscriber_params}) do
    case Subscribers.create_subscriber(subscriber_params) do
      {:ok, _subscriber} ->
        conn
        |> put_flash(:info, "Thanks for subscribing! Check your inbox for a welcome email.")
        |> redirect(to: Routes.page_path(conn, :index))

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Sorry, we couldn't subscribe you with that email.")
        |> redirect(to: Routes.page_path(conn, :index))
    end
  end
end
