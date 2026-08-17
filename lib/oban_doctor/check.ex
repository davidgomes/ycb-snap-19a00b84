defmodule ObanDoctor.Check do
  @moduledoc """
  Behaviour for implementing checks.
  """

  alias ObanDoctor.Issue

  @type context :: %{
          workers: list(map()),
          oban_configs: list(map()),
          project_root: String.t()
        }

  @doc """
  Returns the check's unique identifier.
  """
  @callback id() :: atom()

  @doc """
  Returns a human-readable description of what this check does.
  """
  @callback description() :: String.t()

  @doc """
  Returns the default severity for issues found by this check.
  """
  @callback default_severity() :: Issue.severity()

  @doc """
  Runs the check and returns a list of issues found.
  """
  @callback run(context()) :: [Issue.t()]

  @doc """
  Returns the category of the check (:worker or :config).
  """
  @callback category() :: :worker | :config

  @optional_callbacks [category: 0]

  defmacro __using__(opts) do
    category = Keyword.get(opts, :category, :worker)

    quote do
      @behaviour ObanDoctor.Check

      alias ObanDoctor.Issue

      @impl true
      def category, do: unquote(category)

      defoverridable category: 0
    end
  end
end
