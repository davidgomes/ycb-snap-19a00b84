defmodule NewsletterWeb.SubscriptionControllerTest do
  use NewsletterWeb.ConnCase
  import Swoosh.TestAssertions

  describe "POST /subscriptions" do
    test "subscribes a valid subscriber and sends a welcome email", %{conn: conn} do
      conn =
        post(conn, Routes.subscription_path(conn, :create), %{
          "subscriber" => %{"name" => "Grace Hopper", "email" => "grace@example.com"}
        })

      assert redirected_to(conn) == Routes.page_path(conn, :index)
      assert_email_sent(subject: "Welcome to the DockYard Academy Newsletter")
    end

    test "does not subscribe or send an email with invalid params", %{conn: conn} do
      conn =
        post(conn, Routes.subscription_path(conn, :create), %{
          "subscriber" => %{"email" => "not-an-email"}
        })

      assert redirected_to(conn) == Routes.page_path(conn, :index)
      assert_no_emails_sent()
    end
  end
end
