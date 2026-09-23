defmodule NewsletterWeb.SubscriberControllerTest do
  use NewsletterWeb.ConnCase

  import Swoosh.TestAssertions

  @valid_attrs %{name: "Ada Lovelace", email: "ada@example.com"}

  test "sends a welcome email when a subscriber is created", %{conn: conn} do
    conn = post(conn, Routes.subscriber_path(conn, :create), subscriber: @valid_attrs)

    assert redirected_to(conn) == Routes.page_path(conn, :index)

    assert_email_sent(
      subject: "Welcome to the DockYard Academy Newsletter",
      to: [{"Ada Lovelace", "ada@example.com"}],
      text_body: "Hello Ada Lovelace"
    )
  end

  test "does not send a welcome email when signup fails", %{conn: conn} do
    conn = post(conn, Routes.subscriber_path(conn, :create), subscriber: %{name: "", email: ""})

    assert html_response(conn, 200) =~ "Subscribe"
    assert_no_email_sent()
  end
end
