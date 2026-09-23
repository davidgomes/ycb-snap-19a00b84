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
  Check if the resource is required, defaults to true
  """
  @spec required?(Keyword.t()) :: boolean
  def required?(opts) do
    !!Keyword.get(opts, :required, true)
  end

  @doc """
  Check if the resource should always be loaded from the database.

  It's true when `:persisted` (deprecated) or `:required` is explicitly set to true.
  """
  @spec persisted?(Keyword.t()) :: boolean
  def persisted?(opts) do
    !!Keyword.get(opts, :persisted, false) || !!Keyword.get(opts, :required, false)
  end

  @doc ~S"""
  Get the resource name used as the assigns key.

  If the `:as` option is provided, it will be used as the resource name.
  Otherwise it's inferred from the `:model` module name and pluralized for the `:index` action,
  unless the resource is persisted.

      iex> Canary.Utils.get_resource_name(:show, model: MyApp.Post)
      :post

      iex> Canary.Utils.get_resource_name(:index, model: MyApp.Post)
      :posts

      iex> Canary.Utils.get_resource_name(:index, model: MyApp.Post, required: true)
      :post

      iex> Canary.Utils.get_resource_name(:index, model: MyApp.Post, as: :my_posts)
      :my_posts
  """
  @spec get_resource_name(atom, Keyword.t()) :: atom
  def get_resource_name(action, opts) do
    case opts[:as] do
      nil ->
        opts[:model]
        |> Module.split()
        |> List.last()
        |> Macro.underscore()
        |> pluralize_if_needed(action, opts)
        |> String.to_atom()

      as ->
        as
    end
  end

  defp pluralize_if_needed(name, action, opts) do
    if action in [:index] and not persisted?(opts) do
      name <> "s"
    else
      name
    end
  end

  @doc ~S"""
  Get the list of actions for which the model module name is used instead of a loaded resource.

      iex> Canary.Utils.non_id_actions([])
      [:index, :new, :create]

      iex> Canary.Utils.non_id_actions(non_id_actions: [:find_by_name])
      [:index, :new, :create, :find_by_name]
  """
  @spec non_id_actions(Keyword.t()) :: [atom]
  def non_id_actions(opts) do
    Enum.concat([:index, :new, :create], Keyword.get(opts, :non_id_actions, []))
  end

  @doc """
  Check if the not found handler should be applied for the given action, assigns and options.
  """
  @spec apply_handle_not_found?(atom, map, Keyword.t()) :: boolean
  def apply_handle_not_found?(action, assigns, opts) do
    resource = Map.get(assigns, get_resource_name(action, opts))

    is_nil(resource) and (required?(opts) or action not in non_id_actions(opts))
  end

  @doc false
  @spec validate_opts(Keyword.t()) :: Keyword.t()
  def validate_opts(opts) do
    if Keyword.has_key?(opts, :persisted) do
      IO.warn(
        "The `:persisted` option is deprecated and will be removed in Canary 2.1.0. " <>
          "Use `:required` instead. Check the documentation for more information."
      )
    end

    if Keyword.has_key?(opts, :non_id_actions) do
      IO.warn(
        "The `:non_id_actions` option is deprecated and will be removed in Canary 2.1.0. " <>
          "Use a separate `:authorize_resource` plug with `required: false` for non-id actions " <>
          "and `:except` to skip them in other plugs. Check the documentation for more information."
      )
    end

    opts
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
