defmodule NewsletterWeb.PageControllerTest do
  use NewsletterWeb.ConnCase

  import Swoosh.TestAssertions

  test "GET /", %{conn: conn} do
    conn = get(conn, "/")
    assert html_response(conn, 200) =~ "Welcome to Phoenix!"
  end

  describe "POST /subscribe" do
    test "sends a welcome email to the new subscriber", %{conn: conn} do
      conn =
        post(conn, Routes.page_path(conn, :subscribe), %{
          "subscriber" => %{"name" => "Peter", "email" => "peter@example.com"}
        })

      assert redirected_to(conn) == Routes.page_path(conn, :index)
      assert get_flash(conn, :info) =~ "peter@example.com"

      assert_email_sent(
        Newsletter.Emails.welcome(%{name: "Peter", email: "peter@example.com"})
      )
    end

    test "does not send an email when fields are missing", %{conn: conn} do
      conn =
        post(conn, Routes.page_path(conn, :subscribe), %{
          "subscriber" => %{"name" => "", "email" => "peter@example.com"}
        })

      assert redirected_to(conn) == Routes.page_path(conn, :index)
      assert get_flash(conn, :error) =~ "name and email"
      assert_no_email_sent()
    end
  end
end
