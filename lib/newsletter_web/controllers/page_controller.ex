defmodule NewsletterWeb.PageController do
  use NewsletterWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end

  def subscribe(conn, %{"name" => name, "email" => email}) do
    %{name: name, email: email}
    |> Newsletter.Emails.welcome()
    |> Newsletter.Mailer.deliver()

    conn
    |> put_flash(:info, "Thanks for subscribing, #{name}!")
    |> redirect(to: Routes.page_path(conn, :index))
  end
end
