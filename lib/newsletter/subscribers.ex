defmodule Newsletter.Subscribers do
  @moduledoc """
  The Subscribers context.
  """

  import Ecto.Query, warn: false
  alias Newsletter.Repo

  alias Newsletter.Subscribers.Subscriber

  def list_subscribers do
    Repo.all(Subscriber)
  end

  def get_subscriber!(id), do: Repo.get!(Subscriber, id)

  def create_subscriber(attrs \\ %{}) do
    %Subscriber{}
    |> Subscriber.changeset(attrs)
    |> Repo.insert()
  end

  def update_subscriber(%Subscriber{} = subscriber, attrs) do
    subscriber
    |> Subscriber.changeset(attrs)
    |> Repo.update()
  end

  def delete_subscriber(%Subscriber{} = subscriber) do
    Repo.delete(subscriber)
  end

  def change_subscriber(%Subscriber{} = subscriber, attrs \\ %{}) do
    Subscriber.changeset(subscriber, attrs)
  end
end
