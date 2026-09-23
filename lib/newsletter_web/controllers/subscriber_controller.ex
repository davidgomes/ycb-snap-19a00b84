defmodule NewsletterWeb.SubscriberController do
  use NewsletterWeb, :controller

  require Logger

  alias Newsletter.Emails
  alias Newsletter.Mailer
  alias Newsletter.Subscribers
  alias Newsletter.Subscribers.Subscriber

  def new(conn, _params) do
    changeset = Subscribers.change_subscriber(%Subscriber{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"subscriber" => subscriber_params}) do
    case Subscribers.create_subscriber(subscriber_params) do
      {:ok, subscriber} ->
        send_welcome_email(subscriber)

        conn
        |> put_flash(:info, "Thanks for subscribing!")
        |> redirect(to: Routes.page_path(conn, :index))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  defp send_welcome_email(subscriber) do
    case subscriber |> Emails.welcome() |> Mailer.deliver() do
      {:ok, _metadata} ->
        :ok

      {:error, reason} ->
        Logger.warning(
          "Failed to send welcome email to subscriber #{subscriber.id}: #{inspect(reason)}"
        )
    end
  end
end
