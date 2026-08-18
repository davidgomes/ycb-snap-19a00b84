defmodule NewsletterWeb.SubscriberControllerTest do
  use NewsletterWeb.ConnCase

  import Swoosh.TestAssertions

  describe "GET /subscribe" do
    test "renders the subscription form", %{conn: conn} do
      conn = get(conn, Routes.subscriber_path(conn, :new))
      assert html_response(conn, 200) =~ "Subscribe to the newsletter"
    end
  end

  describe "POST /subscribe" do
    test "subscribes and welcomes the new subscriber", %{conn: conn} do
      params = %{"name" => "Brooklin", "email" => "brooklin@example.com"}
      conn = post(conn, Routes.subscriber_path(conn, :create), subscriber: params)

      assert redirected_to(conn) == Routes.page_path(conn, :index)
      assert get_flash(conn, :info) =~ "Subscribed!"

      assert_email_sent(
        to: [{"Brooklin", "brooklin@example.com"}],
        subject: "Welcome to the DockYard Academy Newsletter"
      )
    end

    test "renders errors when the params are invalid", %{conn: conn} do
      conn = post(conn, Routes.subscriber_path(conn, :create), subscriber: %{"name" => ""})

      assert html_response(conn, 200) =~ "Oops, something went wrong!"
      refute_email_sent()
    end
  end
end
