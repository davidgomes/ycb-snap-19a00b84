defmodule Newsletter.SubscribersTest do
  use Newsletter.DataCase

  alias Newsletter.Subscribers

  describe "subscribers" do
    alias Newsletter.Subscribers.Subscriber

    import Newsletter.SubscribersFixtures

    @invalid_attrs %{email: nil, name: nil}

    test "list_subscribers/0 returns all subscribers" do
      subscriber = subscriber_fixture()
      assert Subscribers.list_subscribers() == [subscriber]
    end

    test "get_subscriber!/1 returns the subscriber with given id" do
      subscriber = subscriber_fixture()
      assert Subscribers.get_subscriber!(subscriber.id) == subscriber
    end

    test "create_subscriber/1 with valid data creates a subscriber" do
      valid_attrs = %{email: "some email", name: "some name"}

      assert {:ok, %Subscriber{} = subscriber} = Subscribers.create_subscriber(valid_attrs)
      assert subscriber.email == "some email"
      assert subscriber.name == "some name"
    end

    test "create_subscriber/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Subscribers.create_subscriber(@invalid_attrs)
    end
  end
end
