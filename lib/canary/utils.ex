defmodule Canary.Utils do
  @moduledoc """
  Common utils functions for `Canary.Plugs` and `Canary.Hooks`
  """

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
        params[to_string(id_name)]
    end
  end

  @doc """
  Get the key under which the resource is stored in assigns.

  It's either the `:as` option or it's inferred from the model name - the most specific
  (right most) name in the model's module name converted to underscore case.

      iex> Canary.Utils.get_resource_name(model: Some.Project.BlogPost)
      :blog_post

      iex> Canary.Utils.get_resource_name(model: Post, as: :my_post)
      :my_post
  """
  @doc since: "2.0.0"
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
  Get the subject for the authorization from the conn or socket assigns.

  The assigns key is taken from the `:current_user` option, then from
  `config :canary, current_user: key`, and defaults to `:current_user`.

  Raises `KeyError` when the key is not present in assigns.
  """
  @doc since: "2.0.0"
  @spec get_current_user(Plug.Conn.t() | Phoenix.LiveView.Socket.t(), Keyword.t()) :: any
  def get_current_user(%{assigns: assigns}, opts) do
    current_user_name =
      opts[:current_user] || Application.get_env(:canary, :current_user, :current_user)

    Map.fetch!(assigns, current_user_name)
  end

  @doc """
  Get the resource already present in the conn or socket assigns.

  Returns `nil` unless the resource assigned under `get_resource_name/1` is a `opts[:model]` struct.
  """
  @doc since: "2.0.0"
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
  Get the resource from the conn or socket assigns, or load it from the repo when it's not assigned yet.

  An already assigned resource of the `opts[:model]` type is never clobbered.
  """
  @doc since: "2.0.0"
  @spec get_resource(Plug.Conn.t() | Phoenix.LiveView.Socket.t(), map(), Keyword.t()) ::
          Ecto.Schema.t() | nil
  def get_resource(conn_or_socket, params, opts) do
    get_assigned_resource(conn_or_socket, opts) || repo_get_resource(params, opts)
  end

  @doc """
  Load the resource from the configured repo.

  The resource is looked up by the `:id_field` (defaults to `:id`) using the value
  from `params` given by `get_resource_id/2`. Both `:id_name` and `:id_field` accept
  an atom or a string.
  """
  @doc since: "2.0.0"
  @spec repo_get_resource(map(), Keyword.t()) :: Ecto.Schema.t() | nil
  def repo_get_resource(params, opts) do
    repo = Application.get_env(:canary, :repo)
    field_name = opts |> Keyword.get(:id_field, :id) |> to_string() |> String.to_atom()

    repo.get_by(opts[:model], %{field_name => get_resource_id(params, opts)})
    |> preload_if_needed(repo, opts)
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
  Apply the error handler to the connection or socket.

  The handler is resolved in the following order:

  1. `opts[handler_key]` - a `{mod, fun}` tuple or a module implementing `Canary.ErrorHandler`
  2. `opts[:error_handler]` - a module implementing `Canary.ErrorHandler`
  3. `config :canary, error_handler: module`
  4. `Canary.DefaultHandler`
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
        Keyword.get(opts, :error_handler) ||
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
