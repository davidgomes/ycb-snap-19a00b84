defmodule Newsletter.Subscribers do
  @moduledoc """
  The Subscribers context.
  """

  alias Newsletter.Repo
  alias Newsletter.Subscribers.Subscriber

  def create_subscriber(attrs \\ %{}) do
    %Subscriber{}
    |> Subscriber.changeset(attrs)
    |> Repo.insert()
  end

  def change_subscriber(%Subscriber{} = subscriber, attrs \\ %{}) do
    Subscriber.changeset(subscriber, attrs)
  end
end
