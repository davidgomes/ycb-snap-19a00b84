defmodule NewsletterWeb.PageControllerTest do
  use NewsletterWeb.ConnCase

  import Swoosh.TestAssertions

  test "GET /", %{conn: conn} do
    conn = get(conn, "/")
    assert html_response(conn, 200) =~ "Welcome to Phoenix!"
  end

  test "POST /subscribe sends a welcome email", %{conn: conn} do
    conn =
      post(conn, Routes.page_path(conn, :subscribe), %{
        "user" => %{"name" => "Jane", "email" => "jane@example.com"}
      })

    assert redirected_to(conn) == Routes.page_path(conn, :index)
    assert get_flash(conn, :info) =~ "Thanks for subscribing, Jane!"

    assert_email_sent(Newsletter.Emails.welcome(%{name: "Jane", email: "jane@example.com"}))
  end
end
