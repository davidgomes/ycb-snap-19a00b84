defmodule NewsletterWeb.PageController do
  use NewsletterWeb, :controller

  alias Newsletter.{Emails, Mailer}

  def index(conn, _params) do
    render(conn, "index.html")
  end

  def subscribe(conn, %{"user" => %{"name" => name, "email" => email}}) do
    %{name: name, email: email}
    |> Emails.welcome()
    |> Mailer.deliver()
    |> case do
      {:ok, _metadata} ->
        conn
        |> put_flash(
          :info,
          "Thanks for subscribing, #{name}! Check your inbox for a welcome email."
        )
        |> redirect(to: Routes.page_path(conn, :index))

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Something went wrong sending your welcome email. Please try again.")
        |> redirect(to: Routes.page_path(conn, :index))
    end
  end
end
