defmodule Hexpm.AdminTasks.Reasons do
  @moduledoc """
  Reasons given to people when the Hex.pm team removes their package,
  release or account.

  A reason is either one of the ids below or free text written for the case
  at hand. The emails already say what was removed in the sentence before
  the reason, so reason texts never name the package, version or username.
  """

  @type scope() :: :package | :release | :user

  @scopes [:package, :release, :user]

  @reasons [
    %{
      id: :seo_spam,
      scopes: [:package, :release, :user],
      text:
        "Hex.pm does not accept packages published to advertise a website. " <>
          "What was published provided no working software, only links and text " <>
          "promoting an unrelated site."
    },
    %{
      id: :empty,
      scopes: [:package, :release],
      text:
        "Packages published to Hex.pm must contain some functionality. " <>
          "What was published contained no working code."
    },
    %{
      id: :name_squatting,
      scopes: [:package],
      text:
        "Publishing a package to reserve its name is not allowed on Hex.pm. " <>
          "Package names are available to projects that publish working code under them."
    },
    %{
      id: :typosquatting,
      scopes: [:package],
      text:
        "The name was chosen to be easily mistaken for an existing package. " <>
          "Hex.pm does not allow names that are intentionally confusing or misleading."
    },
    %{
      id: :copyright,
      scopes: [:package, :release],
      text:
        "What was published infringed on the copyright or license of another work. " <>
          "You may only publish content to Hex.pm that you have the right to distribute."
    },
    %{
      id: :undisclosed_behaviour,
      scopes: [:package, :release],
      text:
        "The code performed actions that were not disclosed in its description or " <>
          "documentation. Packages on Hex.pm must not hide what they do from the people " <>
          "who depend on them."
    },
    %{
      id: :malware,
      scopes: [:package, :release, :user],
      text:
        "What was published contained code designed to maliciously exploit or damage " <>
          "the systems it runs on. Malware is not allowed on Hex.pm."
    },
    %{
      id: :spam_account,
      scopes: [:user],
      text:
        "The account was used to publish spam rather than software. " <>
          "Hex.pm accounts are for publishing and maintaining Hex packages."
    },
    %{
      id: :owner_request,
      scopes: [:package, :release, :user],
      text: "This was done at the request of the owner."
    },
    %{
      id: :terms_of_service,
      scopes: [:package, :release, :user],
      text: "This was in violation of the Hex.pm Terms of Service or Code of Conduct."
    }
  ]

  @doc """
  Lists the `{id, text}` of every reason that can be given for `scope`.
  """
  @spec all(scope()) :: [{atom(), String.t()}]
  def all(scope) when scope in @scopes do
    for %{id: id, scopes: scopes, text: text} <- @reasons, scope in scopes, do: {id, text}
  end

  @doc """
  Resolves a reason id or free text into the text sent to the affected people.

  `nil` resolves to `nil`, meaning no reason was given and nobody is notified.
  """
  @spec resolve(atom() | String.t() | nil, scope()) :: {:ok, String.t() | nil} | {:error, term()}
  def resolve(nil, _scope), do: {:ok, nil}

  def resolve(id, scope) when is_atom(id) and scope in @scopes do
    case Enum.find(@reasons, &(&1.id == id)) do
      nil ->
        {:error, {:unknown_reason, id}}

      %{scopes: scopes, text: text} ->
        if scope in scopes do
          {:ok, text}
        else
          {:error, {:reason_not_applicable, id, scope}}
        end
    end
  end

  def resolve(text, scope) when is_binary(text) and scope in @scopes do
    case String.trim(text) do
      "" -> {:error, :blank_reason}
      text -> {:ok, text}
    end
  end
end
