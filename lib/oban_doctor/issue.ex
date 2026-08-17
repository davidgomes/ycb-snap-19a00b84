defmodule ObanDoctor.Issue do
  @moduledoc """
  Represents an issue found during analysis.
  """

  @type severity :: :error | :warning | :info

  @type t :: %__MODULE__{
          check: module(),
          severity: severity(),
          message: String.t(),
          file: String.t() | nil,
          line: pos_integer() | nil,
          meta: map()
        }

  @enforce_keys [:check, :severity, :message]
  defstruct [:check, :severity, :message, :file, :line, meta: %{}]

  @doc """
  Creates a new issue.
  """
  def new(attrs) when is_list(attrs) do
    struct!(__MODULE__, attrs)
  end

  @doc """
  Returns a human-readable check name from the module.
  """
  def check_name(%__MODULE__{check: check}) do
    check
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
    |> String.replace("_", " ")
    |> String.capitalize()
  end
end
