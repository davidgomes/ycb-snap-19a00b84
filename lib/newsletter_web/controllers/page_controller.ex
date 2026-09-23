defmodule NewsletterWeb.PageController do
  use NewsletterWeb, :controller

  alias Newsletter.{Emails, Mailer}

  def index(conn, _params) do
    render(conn, "index.html")
  end

  def subscribe(conn, %{"subscriber" => %{"name" => name, "email" => email}}) do
    case %{name: name, email: email} |> Emails.welcome() |> Mailer.deliver() do
      {:ok, _metadata} ->
        conn
        |> put_flash(:info, "Thanks for subscribing! Check your inbox for a welcome message.")
        |> redirect(to: Routes.page_path(conn, :index))

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Sorry, we couldn't send your welcome message. Please try again.")
        |> redirect(to: Routes.page_path(conn, :index))
    end
  end
end
