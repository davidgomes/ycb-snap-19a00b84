defmodule Newsletter.SubscribersTest do
  use Newsletter.DataCase

  alias Newsletter.Subscribers
  alias Newsletter.Subscribers.Subscriber

  @valid_attrs %{name: "Jane Doe", email: "jane@example.com"}

  describe "create_subscriber/1" do
    test "with valid data creates a subscriber" do
      assert {:ok, %Subscriber{} = subscriber} = Subscribers.create_subscriber(@valid_attrs)
      assert subscriber.name == "Jane Doe"
      assert subscriber.email == "jane@example.com"
    end

    test "requires name and email" do
      assert {:error, changeset} = Subscribers.create_subscriber(%{})
      assert %{name: ["can't be blank"], email: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects malformed emails" do
      assert {:error, changeset} =
               Subscribers.create_subscriber(%{@valid_attrs | email: "not an email"})

      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
    end

    test "rejects duplicate emails" do
      assert {:ok, _subscriber} = Subscribers.create_subscriber(@valid_attrs)
      assert {:error, changeset} = Subscribers.create_subscriber(@valid_attrs)
      assert %{email: ["has already been taken"]} = errors_on(changeset)
    end
  end

  test "change_subscriber/1 returns a subscriber changeset" do
    assert %Ecto.Changeset{} = Subscribers.change_subscriber(%Subscriber{})
  end
end
