defmodule NewsletterWeb.PageControllerTest do
  use NewsletterWeb.ConnCase

  import Swoosh.TestAssertions

  test "GET /", %{conn: conn} do
    conn = get(conn, "/")
    assert html_response(conn, 200) =~ "Welcome to Phoenix!"
  end

  test "GET / renders the subscribe form", %{conn: conn} do
    conn = get(conn, "/")
    html = html_response(conn, 200)
    assert html =~ ~s(action="/subscribe")
    assert html =~ ~s(name="subscriber[email]")
  end

  describe "POST /subscribe" do
    test "sends a welcome email to the new subscriber", %{conn: conn} do
      conn =
        post(conn, Routes.page_path(conn, :subscribe),
          subscriber: %{name: "Jane", email: "jane@example.com"}
        )

      assert redirected_to(conn) == Routes.page_path(conn, :index)
      assert get_flash(conn, :info) =~ "Thanks for subscribing"

      assert_email_sent(
        to: [{"Jane", "jane@example.com"}],
        subject: "Welcome to the DockYard Academy Newsletter"
      )
    end
  end
end
