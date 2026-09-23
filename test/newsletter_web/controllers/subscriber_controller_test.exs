defmodule NewsletterWeb.SubscriberControllerTest do
  use NewsletterWeb.ConnCase

  import Swoosh.TestAssertions

  alias Newsletter.Emails
  alias Newsletter.Repo
  alias Newsletter.Subscribers.Subscriber

  @create_attrs %{name: "Jane Doe", email: "jane@example.com"}
  @invalid_attrs %{name: nil, email: nil}

  describe "new subscriber" do
    test "renders form", %{conn: conn} do
      conn = get(conn, Routes.subscriber_path(conn, :new))
      assert html_response(conn, 200) =~ "Subscribe to the Newsletter"
    end
  end

  describe "create subscriber" do
    test "saves the subscriber and sends them a welcome email", %{conn: conn} do
      conn = post(conn, Routes.subscriber_path(conn, :create), subscriber: @create_attrs)

      assert redirected_to(conn) == Routes.page_path(conn, :index)
      assert get_flash(conn, :info) == "Thanks for subscribing!"

      subscriber = Repo.get_by!(Subscriber, email: "jane@example.com")
      assert_email_sent(Emails.welcome(subscriber))
    end

    test "renders errors and sends no email when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.subscriber_path(conn, :create), subscriber: @invalid_attrs)

      assert html_response(conn, 200) =~ "Subscribe to the Newsletter"
      assert Repo.aggregate(Subscriber, :count) == 0
      assert_no_email_sent()
    end
  end
end
