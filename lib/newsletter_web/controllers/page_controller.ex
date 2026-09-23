defmodule NewsletterWeb.PageController do
  use NewsletterWeb, :controller

  alias Newsletter.{Emails, Mailer}

  def index(conn, _params) do
    render(conn, "index.html")
  end

  def subscribe(conn, %{"subscriber" => %{"name" => name, "email" => email}})
      when name != "" and email != "" do
    case %{name: name, email: email} |> Emails.welcome() |> Mailer.deliver() do
      {:ok, _metadata} ->
        conn
        |> put_flash(:info, "Thanks for subscribing! A welcome email is on its way to #{email}.")
        |> redirect(to: Routes.page_path(conn, :index))

      {:error, _reason} ->
        conn
        |> put_flash(:error, "We couldn't send your welcome email. Please try again.")
        |> redirect(to: Routes.page_path(conn, :index))
    end
  end

  def subscribe(conn, _params) do
    conn
    |> put_flash(:error, "Please provide your name and email to subscribe.")
    |> redirect(to: Routes.page_path(conn, :index))
  end
end
