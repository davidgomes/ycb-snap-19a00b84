defmodule NewsletterWeb.PageControllerTest do
  use NewsletterWeb.ConnCase

  import Swoosh.TestAssertions

  test "GET /", %{conn: conn} do
    conn = get(conn, "/")
    assert html_response(conn, 200) =~ "Welcome to Phoenix!"
  end

  describe "POST /subscribe" do
    test "sends a welcome email to the new subscriber", %{conn: conn} do
      subscriber = %{name: "Jane", email: "jane@example.com"}

      conn = post(conn, Routes.page_path(conn, :subscribe), subscriber: subscriber)

      assert redirected_to(conn) == Routes.page_path(conn, :index)
      assert get_flash(conn, :info) =~ "Thanks for subscribing"
      assert_email_sent(Newsletter.Emails.welcome(subscriber))
    end

    test "does not send an email when fields are missing", %{conn: conn} do
      conn =
        post(conn, Routes.page_path(conn, :subscribe), subscriber: %{name: "", email: ""})

      assert redirected_to(conn) == Routes.page_path(conn, :index)
      assert get_flash(conn, :error) =~ "Please provide"
      assert_no_email_sent()
    end
  end
end
