defmodule NewsletterWeb.PageControllerTest do
  use NewsletterWeb.ConnCase
  import Swoosh.TestAssertions

  test "GET /", %{conn: conn} do
    conn = get(conn, "/")
    assert html_response(conn, 200) =~ "Welcome to Phoenix!"
  end

  test "POST /subscribe sends a welcome email", %{conn: conn} do
    conn = post(conn, "/subscribe", subscriber: %{name: "Ada", email: "ada@example.com"})
    assert redirected_to(conn) == "/"
    assert_email_sent(Newsletter.Emails.welcome(%{name: "Ada", email: "ada@example.com"}))
  end
end
