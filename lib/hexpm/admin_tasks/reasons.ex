defmodule Hexpm.AdminTasks.Reasons do
  @moduledoc """
  Reasons for removing a package, release or user account.

  A reason is sent to the people affected by a removal. Each reason declares
  the scopes it applies to so it can only be used for removals it makes sense
  for.

  Reason texts never name the package, version or username, the email already
  names what was removed right before the reason. This lets a single text
  serve every scope.
  """

  @type scope() :: :package | :release | :user

  @reasons [
    %{
      id: :seo_spam,
      scopes: [:package, :release, :user],
      text: """
      Hex.pm does not accept packages published to advertise a website. What was \
      published provided no working software, only links and text pointing at an \
      unrelated site.\
      """
    },
    %{
      id: :empty,
      scopes: [:package, :release],
      text: """
      Hex.pm is for sharing working software. What was published contained no \
      functional code, only placeholder or generated files.\
      """
    },
    %{
      id: :name_squatting,
      scopes: [:package],
      text: """
      Reserving package names without publishing working software is not allowed. \
      The name was held without any functional code, which prevents others from \
      using it for a real project.\
      """
    },
    %{
      id: :typosquatting,
      scopes: [:package],
      text: """
      The name closely imitates the name of an existing package in a way that is \
      likely to mislead people into installing the wrong package.\
      """
    },
    %{
      id: :copyright,
      scopes: [:package, :release],
      text: """
      We received a complaint that what was published infringes the copyright or \
      other intellectual property rights of a third party. Our copyright policy \
      is available at https://hex.pm/policies/copyright.\
      """
    },
    %{
      id: :undisclosed_behaviour,
      scopes: [:package, :release],
      text: """
      What was published performed actions that were not disclosed in its \
      description or documentation, such as collecting data, contacting remote \
      servers or modifying the system it runs on.\
      """
    },
    %{
      id: :malware,
      scopes: [:package, :release, :user],
      text: """
      What was published contained code intended to harm the systems or data of \
      the people who install it.\
      """
    },
    %{
      id: :spam_account,
      scopes: [:user],
      text: """
      The account was used only to publish spam or content unrelated to sharing \
      software on Hex.pm.\
      """
    },
    %{
      id: :owner_request,
      scopes: [:package, :release, :user],
      text: """
      The removal was made at the request of the owner.\
      """
    },
    %{
      id: :terms_of_service,
      scopes: [:package, :release, :user],
      text: """
      What was published violates the Hex.pm Terms of Service, available at \
      https://hex.pm/policies/termsofservice.\
      """
    }
  ]

  @doc """
  Lists the reasons applicable to the given scope as `{id, text}` tuples.
  """
  @spec list(scope()) :: [{atom(), String.t()}]
  def list(scope) do
    for reason <- @reasons, scope in reason.scopes, do: {reason.id, reason.text}
  end

  @doc """
  Resolves a reason to the text that is sent in the email.

  A reason is either the id of a known reason applicable to `scope` or a
  custom text. `nil` resolves to `nil`, meaning no email is sent.
  """
  @spec resolve(atom() | String.t() | nil, scope()) ::
          {:ok, String.t() | nil}
          | {:error,
             :empty_reason
             | {:unknown_reason, atom()}
             | {:invalid_reason_scope, atom(), scope()}}
  def resolve(nil, _scope), do: {:ok, nil}

  def resolve(text, _scope) when is_binary(text) do
    case String.trim(text) do
      "" -> {:error, :empty_reason}
      text -> {:ok, text}
    end
  end

  def resolve(id, scope) when is_atom(id) do
    case Enum.find(@reasons, &(&1.id == id)) do
      nil ->
        {:error, {:unknown_reason, id}}

      reason ->
        if scope in reason.scopes do
          {:ok, reason.text}
        else
          {:error, {:invalid_reason_scope, id, scope}}
        end
    end
  end
end
