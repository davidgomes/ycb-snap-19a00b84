defmodule Newsletter.SubscribersTest do
  use Newsletter.DataCase
  import Swoosh.TestAssertions

  alias Newsletter.Subscribers

  describe "create_subscriber/1" do
    test "creates a subscriber and sends a welcome email with valid data" do
      attrs = %{"name" => "Ada Lovelace", "email" => "ada@example.com"}

      assert {:ok, subscriber} = Subscribers.create_subscriber(attrs)
      assert subscriber.email == "ada@example.com"
      assert_email_sent(subject: "Welcome to the DockYard Academy Newsletter")
    end

    test "returns an error changeset and sends no email with invalid data" do
      assert {:error, changeset} = Subscribers.create_subscriber(%{"email" => "not-an-email"})
      assert %{email: ["must be a valid email"]} = errors_on(changeset)
      assert_no_emails_sent()
    end
  end
end
