defmodule Oban.Console do
  @moduledoc """
  Documentation for `ObanConsole`.
  """

  @doc """
  Hello world.

  ## Examples

      iex> ObanConsole.hello()
      :world

  """
  defdelegate list_queues(), to: Oban.Console.Queues, as: :list
end
