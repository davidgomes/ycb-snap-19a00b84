defmodule Hexpm.AdminTasks.Reasons do
  @moduledoc """
  Reasons given to people when the Hex.pm team removes their package, release
  or account.

  Reason texts are shown below a sentence that already names the package,
  version or username, so they must not name them again. This lets one text
  serve every scope it applies to.
  """

  @type scope() :: :package | :release | :user
  @type reason() :: atom() | String.t()

  @reasons [
    seo_spam: %{
      scopes: [:package, :release, :user],
      text:
        "Hex.pm does not accept packages published to advertise a website. " <>
          "What was published provided no working software, only links and text " <>
          "pointing at an unrelated site."
    },
    empty: %{
      scopes: [:package, :release],
      text:
        "Hex.pm is a registry for working software. What was published contained " <>
          "no functional code, so it took up a name without providing anything to " <>
          "the people who might find it."
    },
    name_squatting: %{
      scopes: [:package],
      text:
        "Hex.pm does not allow reserving package names without publishing working " <>
          "software under them. The name has been released so it can be used by an " <>
          "active project."
    },
    typosquatting: %{
      scopes: [:package],
      text:
        "The name closely resembles an existing package, which risks people " <>
          "installing it by mistake. Hex.pm does not allow names chosen to be " <>
          "confused with other packages."
    },
    copyright: %{
      scopes: [:package, :release],
      text:
        "We received a report that what was published infringes on the copyright " <>
          "or license of someone else's work. See the copyright policy at " <>
          "https://hex.pm/policies/copyright for more information."
    },
    undisclosed_behaviour: %{
      scopes: [:package, :release],
      text:
        "What was published performed actions that were not disclosed in its " <>
          "description or documentation. Hex.pm requires packages to be clear about " <>
          "what they do, especially when they make network requests, collect data " <>
          "or change anything outside of the project they are added to."
    },
    malware: %{
      scopes: [:package, :release, :user],
      text:
        "What was published contained malicious code intended to harm the systems " <>
          "or people using it. Hex.pm does not allow malicious code and removes it " <>
          "as soon as it is found."
    },
    spam_account: %{
      scopes: [:user],
      text:
        "The account was used to publish spam or to advertise unrelated websites " <>
          "rather than to publish or maintain software."
    },
    owner_request: %{
      scopes: [:package, :release, :user],
      text: "The removal was requested by the owner and carried out by the Hex.pm team."
    },
    terms_of_service: %{
      scopes: [:package, :release, :user],
      text:
        "The Hex.pm terms of service were violated. You can read them at " <>
          "https://hex.pm/policies/termsofservice."
    }
  ]

  @doc """
  Lists the reason ids and texts that apply to the given scope.
  """
  @spec all(scope()) :: [{atom(), String.t()}]
  def all(scope) when scope in [:package, :release, :user] do
    for {id, %{scopes: scopes, text: text}} <- @reasons, scope in scopes, do: {id, text}
  end

  @doc """
  Resolves a reason to the text sent in the removal email.

  A reason is either an id from `all/1` or custom text. `nil` means no reason
  was given and nothing should be sent.
  """
  @spec resolve(reason() | nil, scope()) :: {:ok, String.t() | nil} | {:error, term()}
  def resolve(nil, _scope), do: {:ok, nil}

  def resolve(id, scope) when is_atom(id) do
    case Keyword.fetch(@reasons, id) do
      {:ok, %{scopes: scopes, text: text}} ->
        if scope in scopes do
          {:ok, text}
        else
          {:error, {:reason_not_applicable, id, scope}}
        end

      :error ->
        {:error, {:unknown_reason, id}}
    end
  end

  def resolve(text, _scope) when is_binary(text) do
    case String.trim(text) do
      "" -> {:error, :empty_reason}
      text -> {:ok, text}
    end
  end
end
