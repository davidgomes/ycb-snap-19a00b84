defmodule Canary.Utils do
  @moduledoc """
  Common utils functions for `Canary.Plugs` and `Canary.Hooks`
  """

  import Canada.Can, only: [can?: 3]

  @doc """
  Get the resource id from the connection params

      iex> Canary.Utils.get_resource_id(%{"id" => "9"}, [])
      "9"

      iex> Canary.Utils.get_resource_id(%Plug.Conn{params: %{"custom_id" => "1"}}, id_name: "custom_id")
      "1"

      iex> Canary.Utils.get_resource_id(%{"user_id" => "7"}, id_name: "user_id")
      "7"

      iex> Canary.Utils.get_resource_id(%{"other_id" => "9"}, id_name: "id")
      nil
  """
  @moduledoc since: "2.0.0"

  @spec get_resource_id(Plug.Conn.t(), Keyword.t()) :: String.t() | nil
  def get_resource_id(%Plug.Conn{params: params}, opts) do
    get_resource_id(params, opts)
  end

  @spec get_resource_id(map(), Keyword.t()) :: String.t() | nil
  def get_resource_id(params, opts) when is_map(params) do
    case opts[:id_name] do
      nil ->
        params["id"]

      id_name ->
        params[id_name]
    end
  end

  @doc """
  Preload associations if needed
  """
  @spec preload_if_needed(nil, Ecto.Repo.t(), Keyword.t()) :: nil
  def preload_if_needed(nil, _repo, _opts), do: nil

  @spec preload_if_needed([Ecto.Schema.t()], Ecto.Repo.t(), Keyword.t()) :: [Ecto.Schema.t()]
  def preload_if_needed(records, repo, opts) do
    case opts[:preload] do
      nil ->
        records

      models ->
        repo.preload(records, models)
    end
  end

  @doc ~S"""
  Check if an action is valid based on the options.

      iex> Canary.Utils.action_valid?(:index, only: [:index, :show])
        true

      iex> Canary.Utils.action_valid?(:index, except: :index)
        false

      iex> Canary.Utils.action_valid?(:show, except: :index, only: :show)
        ** (ArgumentError) You can't use both :except and :only options
  """
  @spec action_valid?(atom, Keyword.t()) :: boolean
  def action_valid?(action, opts) do
    cond do
      Keyword.has_key?(opts, :except) && Keyword.has_key?(opts, :only) ->
        raise ArgumentError, "You can't use both :except and :only options"

      Keyword.has_key?(opts, :except) ->
        !action_exempt?(action, opts)

      Keyword.has_key?(opts, :only) ->
        action_included?(action, opts)

      true ->
        true
    end
  end

  defp action_exempt?(action, opts) do
    if is_list(opts[:except]) && action in opts[:except] do
      true
    else
      action == opts[:except]
    end
  end

  defp action_included?(action, opts) do
    if is_list(opts[:only]) && action in opts[:only] do
      true
    else
      action == opts[:only]
    end
  end

  @doc """
  Check if a key is present in a keyword list
  """
  @spec required?(Keyword.t()) :: boolean
  def required?(opts) do
    !!Keyword.get(opts, :required, false)
  end

  @doc """
  Check if the resource should always be loaded from the database, even for non-id actions.

  It's true when either `:persisted` (deprecated) or `:required` is set.

      iex> Canary.Utils.persisted?(persisted: true)
      true

      iex> Canary.Utils.persisted?(required: true)
      true

      iex> Canary.Utils.persisted?([])
      false
  """
  @spec persisted?(Keyword.t()) :: boolean
  def persisted?(opts) do
    !!Keyword.get(opts, :persisted, false) || required?(opts)
  end

  @doc """
  Get the actions which don't use a resource id: `:index`, `:new`, `:create`
  and the ones given in `:non_id_actions`.

      iex> Canary.Utils.non_id_actions([])
      [:index, :new, :create]

      iex> Canary.Utils.non_id_actions(non_id_actions: [:search])
      [:index, :new, :create, :search]
  """
  @spec non_id_actions(Keyword.t()) :: [atom]
  def non_id_actions(opts) do
    if opts[:non_id_actions] do
      Enum.concat([:index, :new, :create], opts[:non_id_actions])
    else
      [:index, :new, :create]
    end
  end

  @doc """
  Get the assigns key of the resource: the `:as` option or the underscored
  name of the `:model` module.

      iex> Canary.Utils.get_resource_name(model: Some.Project.BlogPost)
      :blog_post

      iex> Canary.Utils.get_resource_name(model: Post, as: :my_post)
      :my_post
  """
  @spec get_resource_name(Keyword.t()) :: atom
  def get_resource_name(opts) do
    case opts[:as] do
      nil ->
        opts[:model]
        |> Module.split()
        |> List.last()
        |> Macro.underscore()
        |> String.to_atom()

      as ->
        as
    end
  end

  @doc """
  Get the subject to authorize from the conn or socket assigns.

  The assigns key is `opts[:current_user]`, or the `:current_user` from config, `:current_user` by default.
  Raises `KeyError` when the key is not assigned.
  """
  @spec get_current_user(Plug.Conn.t() | Phoenix.LiveView.Socket.t(), Keyword.t()) :: term
  def get_current_user(%{assigns: assigns}, opts) do
    current_user_name =
      opts[:current_user] || Application.get_env(:canary, :current_user, :current_user)

    Map.fetch!(assigns, current_user_name)
  end

  @doc """
  Get the resource already assigned in the conn or socket, if it's a struct of `opts[:model]`.
  """
  @spec get_assigned_resource(Plug.Conn.t() | Phoenix.LiveView.Socket.t(), Keyword.t()) ::
          Ecto.Schema.t() | nil
  def get_assigned_resource(%{assigns: assigns}, opts) do
    model = opts[:model]

    case Map.get(assigns, get_resource_name(opts)) do
      %{__struct__: ^model} = resource -> resource
      _ -> nil
    end
  end

  @doc """
  Get the resource already assigned in the conn or socket, or fetch it from the repo
  using the id from `params`.

  Returns `nil` when there is no id in `params` or the resource can't be found.
  """
  @spec fetch_resource(Plug.Conn.t() | Phoenix.LiveView.Socket.t(), map, Keyword.t()) ::
          Ecto.Schema.t() | nil
  def fetch_resource(conn_or_socket, params, opts) do
    get_assigned_resource(conn_or_socket, opts) || repo_get_resource(params, opts)
  end

  defp repo_get_resource(params, opts) do
    case get_resource_id(params, opts) do
      nil ->
        nil

      id ->
        repo = Application.get_env(:canary, :repo)
        field_name = Keyword.get(opts, :id_field, "id")

        repo.get_by(opts[:model], %{String.to_atom(field_name) => id})
        |> preload_if_needed(repo, opts)
    end
  end

  @doc """
  Check if the subject is authorized to perform the action on the resource with `Canada.Can.can?/3`.

  For non-id actions the resource is the `opts[:model]` module, unless `:persisted` or `:required` is set.
  Otherwise it's the resource returned by `fetch_resource/3`, which might be `nil`.
  """
  @spec authorized?(Plug.Conn.t() | Phoenix.LiveView.Socket.t(), atom, map, Keyword.t()) ::
          boolean
  def authorized?(conn_or_socket, action, params, opts) do
    current_user = get_current_user(conn_or_socket, opts)

    resource =
      if action in non_id_actions(opts) and not persisted?(opts) do
        opts[:model]
      else
        fetch_resource(conn_or_socket, params, opts)
      end

    can?(current_user, action, resource)
  end

  @doc """
  Apply the error handler to the connection or socket
  """
  @spec apply_error_handler(Plug.Conn.t() , atom, Keyword.t()) :: Plug.Conn.t()
  @spec apply_error_handler(Phoenix.LiveView.Socket.t() , atom, Keyword.t()) :: {:halt, Phoenix.LiveView.Socket.t()}
  def apply_error_handler(conn_or_socket, handler_key, opts) do
    get_handler(handler_key, opts)
    |> apply([conn_or_socket])
  end

  defp get_handler(handler_key, opts) do
    mod_or_mod_fun =
      Keyword.get(opts, handler_key) ||
        Application.get_env(:canary, :error_handler, Canary.DefaultHandler)

    case mod_or_mod_fun do
      {mod, fun} ->
        Function.capture(mod, fun, 1)

      mod when is_atom(mod) ->
        Function.capture(mod, handler_key, 1)

      _ ->
        raise ArgumentError, "
            Invalid error handler, expected a module or a tuple with a module and a function,
            got: #{inspect(mod_or_mod_fun)}"
    end
  end

end
