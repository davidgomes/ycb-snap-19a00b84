defmodule Newsletter.SubscribersTest do
  use Newsletter.DataCase

  import Swoosh.TestAssertions

  alias Newsletter.Emails
  alias Newsletter.Subscribers
  alias Newsletter.Subscribers.Subscriber

  @valid_attrs %{name: "Brooklin", email: "brooklin@example.com"}

  describe "create_subscriber/1" do
    test "stores the subscriber" do
      assert {:ok, %Subscriber{} = subscriber} = Subscribers.create_subscriber(@valid_attrs)
      assert subscriber.name == "Brooklin"
      assert subscriber.email == "brooklin@example.com"
      assert Repo.get!(Subscriber, subscriber.id)
    end

    test "sends the new subscriber a welcome email" do
      assert {:ok, subscriber} = Subscribers.create_subscriber(@valid_attrs)
      assert_email_sent(Emails.welcome(subscriber))
    end

    test "requires a name and an email" do
      assert {:error, changeset} = Subscribers.create_subscriber(%{})

      assert %{name: ["can't be blank"], email: ["can't be blank"]} = errors_on(changeset)
      assert_no_email_sent()
    end

    test "requires the email to look like an email address" do
      assert {:error, changeset} =
               Subscribers.create_subscriber(%{@valid_attrs | email: "brooklin"})

      assert %{email: ["must be a valid email address"]} = errors_on(changeset)
      assert_no_email_sent()
    end

    test "does not welcome the same email twice" do
      assert {:ok, _subscriber} = Subscribers.create_subscriber(@valid_attrs)
      assert_email_sent()

      assert {:error, changeset} = Subscribers.create_subscriber(@valid_attrs)

      assert %{email: ["has already been taken"]} = errors_on(changeset)
      assert_no_email_sent()
    end
  end
end
