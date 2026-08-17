defmodule BadgeForge.Badges do
  @moduledoc """
  The Badges context. Enqueues badge rendering jobs that are executed by
  `BadgeForge.Workers.PythonBadgeRenderer`.
  """

  alias BadgeForge.Workers.PythonBadgeRenderer

  @doc """
  Enqueues an Oban job that renders a badge with the given `label` and
  `value` using the Python renderer.
  """
  def enqueue_render(label, value) when is_binary(label) and is_binary(value) do
    %{"label" => label, "value" => value}
    |> PythonBadgeRenderer.new()
    |> Oban.insert()
  end
end
