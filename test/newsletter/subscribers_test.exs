defmodule Newsletter.SubscribersTest do
  use Newsletter.DataCase

  import Swoosh.TestAssertions

  alias Newsletter.Emails
  alias Newsletter.Subscribers
  alias Newsletter.Subscribers.Subscriber

  @valid_attrs %{name: "Brooklin", email: "brooklin@example.com"}

  describe "create_subscriber/1" do
    test "sends a welcome email to the new subscriber" do
      assert {:ok, %Subscriber{} = subscriber} = Subscribers.create_subscriber(@valid_attrs)

      assert_email_sent(Emails.welcome(subscriber))
    end

    test "does not send a welcome email when the subscriber is invalid" do
      assert {:error, %Ecto.Changeset{}} = Subscribers.create_subscriber(%{name: "Brooklin"})

      refute_email_sent()
    end

    test "does not send a welcome email when the email is already subscribed" do
      assert {:ok, _subscriber} = Subscribers.create_subscriber(@valid_attrs)
      assert_email_sent()

      assert {:error, changeset} = Subscribers.create_subscriber(@valid_attrs)
      assert %{email: ["has already been taken"]} = errors_on(changeset)

      refute_email_sent()
    end
  end
end
