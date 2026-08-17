defmodule NewsletterWeb.SubscriberControllerTest do
  use NewsletterWeb.ConnCase

  import Swoosh.TestAssertions

  @create_attrs %{email: "subscriber@example.com", name: "Ada"}
  @invalid_attrs %{email: nil, name: nil}

  describe "new subscriber" do
    test "renders form", %{conn: conn} do
      conn = get(conn, Routes.subscriber_path(conn, :new))
      assert html_response(conn, 200) =~ "New Subscriber"
    end
  end

  describe "create subscriber" do
    test "creates subscriber, sends welcome email, and redirects", %{conn: conn} do
      conn = post(conn, Routes.subscriber_path(conn, :create), subscriber: @create_attrs)

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == Routes.subscriber_path(conn, :show, id)

      assert_email_sent(fn email ->
        assert email.to == [{"Ada", "subscriber@example.com"}]
        assert email.subject == "Welcome to the DockYard Academy Newsletter"
      end)

      conn = get(conn, Routes.subscriber_path(conn, :show, id))
      assert html_response(conn, 200) =~ "Ada"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.subscriber_path(conn, :create), subscriber: @invalid_attrs)
      assert html_response(conn, 200) =~ "New Subscriber"
      assert_no_email_sent()
    end
  end
end
