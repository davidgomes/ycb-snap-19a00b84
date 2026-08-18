defmodule Newsletter.Subscribers do
  @moduledoc """
  The Subscribers context.
  """

  require Logger

  alias Newsletter.Emails
  alias Newsletter.Mailer
  alias Newsletter.Repo
  alias Newsletter.Subscribers.Subscriber

  @doc """
  Signs someone up for the newsletter and greets them with a welcome email.

  The subscription is kept even when the welcome email cannot be delivered, so a
  failing mail provider never costs us a subscriber.
  """
  def create_subscriber(attrs \\ %{}) do
    changeset = Subscriber.changeset(%Subscriber{}, attrs)

    with {:ok, subscriber} <- Repo.insert(changeset) do
      deliver_welcome(subscriber)
      {:ok, subscriber}
    end
  end

  defp deliver_welcome(subscriber) do
    case subscriber |> Emails.welcome() |> Mailer.deliver() do
      {:ok, _metadata} ->
        :ok

      {:error, reason} ->
        Logger.error(
          "Could not deliver the welcome email to subscriber #{subscriber.id}: #{inspect(reason)}"
        )

        :error
    end
  end
end
