defmodule NewsletterWeb.PageController do
  use NewsletterWeb, :controller

  alias Newsletter.{Emails, Mailer}

  def index(conn, _params) do
    render(conn, "index.html")
  end

  def subscribe(conn, %{"subscriber" => %{"name" => name, "email" => email}})
      when name != "" and email != "" do
    case Emails.welcome(%{name: name, email: email}) |> Mailer.deliver() do
      {:ok, _} ->
        conn
        |> put_flash(
          :info,
          "Thanks for subscribing, #{name}! Check your inbox for a welcome email."
        )
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
