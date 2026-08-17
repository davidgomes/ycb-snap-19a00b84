defmodule BadgeForge.Workers.PythonBadgeRenderer do
  @moduledoc """
  Oban worker that renders a badge by shelling out to the Python script at
  `priv/python/render_badge.py`.

  Enqueue a job with `new/1` and `Oban.insert/1`, e.g.:

      %{"label" => "build", "value" => "passing"}
      |> BadgeForge.Workers.PythonBadgeRenderer.new()
      |> Oban.insert()
  """

  use Oban.Worker, queue: :default, max_attempts: 3

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"label" => label, "value" => value}}) do
    script_path = Application.app_dir(:badge_forge, "priv/python/render_badge.py")
    python = System.find_executable("python3") || "python3"

    case System.cmd(python, [script_path, label, value], stderr_to_stdout: true) do
      {svg, 0} ->
        Logger.info("Rendered badge #{label}=#{value}")
        {:ok, svg}

      {output, exit_code} ->
        {:error, "render_badge.py exited with #{exit_code}: #{output}"}
    end
  end
end
