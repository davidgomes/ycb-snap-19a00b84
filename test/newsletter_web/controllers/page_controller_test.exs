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
        post(conn, "/subscribe", %{
          "subscriber" => %{"name" => "Jane", "email" => "jane@example.com"}
        })

      assert redirected_to(conn) == "/"
      assert get_flash(conn, :info) =~ "Thanks for subscribing, Jane!"

      assert_email_sent(
        to: [{"Jane", "jane@example.com"}],
        subject: "Welcome to the DockYard Academy Newsletter"
      )
    end

    test "does not send an email when fields are missing", %{conn: conn} do
      conn = post(conn, "/subscribe", %{"subscriber" => %{"name" => "", "email" => ""}})

      assert redirected_to(conn) == "/"
      assert get_flash(conn, :error) =~ "Please provide your name and email"
      assert_no_email_sent()
    end
  end
end
