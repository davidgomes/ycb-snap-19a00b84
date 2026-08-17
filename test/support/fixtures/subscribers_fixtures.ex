defmodule Newsletter.SubscribersFixtures do
  def subscriber_fixture(attrs \\ %{}) do
    {:ok, subscriber} =
      attrs
      |> Enum.into(%{
        email: "some email",
        name: "some name"
      })
      |> Newsletter.Subscribers.create_subscriber()

    subscriber
  end
end
