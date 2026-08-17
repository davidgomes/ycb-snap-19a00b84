defmodule Newsletter.Subscribers do
  @moduledoc """
  The Subscribers context handles newsletter subscriptions.
  """

  alias Newsletter.Repo
  alias Newsletter.Subscribers.Subscriber
  alias Newsletter.Emails
  alias Newsletter.Mailer

  @doc """
  Creates a subscriber and sends them a welcome email.

  Returns `{:ok, subscriber}` if the subscriber was persisted and the
  welcome email was sent, or `{:error, changeset}` if the subscriber
  could not be created.
  """
  def create_subscriber(attrs \\ %{}) do
    with {:ok, subscriber} <- insert_subscriber(attrs) do
      send_welcome_email(subscriber)
      {:ok, subscriber}
    end
  end

  defp insert_subscriber(attrs) do
    %Subscriber{}
    |> Subscriber.changeset(attrs)
    |> Repo.insert()
  end

  defp send_welcome_email(subscriber) do
    subscriber
    |> Emails.welcome()
    |> Mailer.deliver()
  end
end
