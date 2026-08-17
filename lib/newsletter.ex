defmodule Newsletter do
  @moduledoc """
  Newsletter keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  alias Newsletter.{Emails, Mailer}

  @doc """
  Sends a welcome email to a newly subscribed user.
  """
  def deliver_welcome_email(user) do
    user
    |> Emails.welcome()
    |> Mailer.deliver()
  end
end
