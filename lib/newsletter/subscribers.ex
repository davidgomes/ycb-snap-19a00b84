defmodule Newsletter.Subscribers do
  @moduledoc """
  The Subscribers context.
  """

  alias Newsletter.Repo
  alias Newsletter.Subscribers.Subscriber

  @doc """
  Creates a subscriber.

  ## Examples

      iex> create_subscriber(%{name: "Jane", email: "jane@example.com"})
      {:ok, %Subscriber{}}

      iex> create_subscriber(%{email: "not an email"})
      {:error, %Ecto.Changeset{}}

  """
  def create_subscriber(attrs \\ %{}) do
    %Subscriber{}
    |> Subscriber.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking subscriber changes.

  ## Examples

      iex> change_subscriber(subscriber)
      %Ecto.Changeset{data: %Subscriber{}}

  """
  def change_subscriber(%Subscriber{} = subscriber, attrs \\ %{}) do
    Subscriber.changeset(subscriber, attrs)
  end
end
