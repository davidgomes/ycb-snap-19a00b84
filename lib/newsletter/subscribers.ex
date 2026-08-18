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
  Returns the list of subscribers.
  """
  def list_subscribers do
    Repo.all(Subscriber)
  end

  @doc """
  Returns a changeset for tracking subscriber changes.
  """
  def change_subscriber(%Subscriber{} = subscriber, attrs \\ %{}) do
    Subscriber.changeset(subscriber, attrs)
  end

  @doc """
  Creates a subscriber and sends them a welcome email.
  """
  def create_subscriber(attrs \\ %{}) do
    with {:ok, subscriber} <- %Subscriber{} |> Subscriber.changeset(attrs) |> Repo.insert() do
      deliver_welcome_email(subscriber)
      {:ok, subscriber}
    end
  end

  # A subscription is still valid even when the welcome email cannot be sent,
  # so delivery failures are logged rather than returned to the caller.
  defp deliver_welcome_email(%Subscriber{} = subscriber) do
    case subscriber |> Emails.welcome() |> Mailer.deliver() do
      {:ok, _metadata} ->
        :ok

      {:error, reason} ->
        Logger.error("could not deliver welcome email to #{subscriber.email}: #{inspect(reason)}")

        :error
    end
  end
end
