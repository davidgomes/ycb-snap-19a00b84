defmodule BadgeForge.Workers.PythonWorker do
  @moduledoc """
  Oban worker that runs a Python script and returns its JSON output.

  Jobs are enqueued from Elixir via `BadgeForge.Workers.PythonWorker.enqueue/1`
  and executed asynchronously by Oban, which shells out to `python3` to run
  `priv/python/badge.py`.
  """

  use Oban.Worker, queue: :default, max_attempts: 3

  @script_path Path.join([:code.priv_dir(:badge_forge), "python", "badge.py"])

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    payload = JSON.encode!(args)

    case System.cmd("python3", [@script_path, payload], stderr_to_stdout: true) do
      {output, 0} ->
        {:ok, JSON.decode!(output)}

      {output, exit_code} ->
        {:error, "python3 exited with status #{exit_code}: #{output}"}
    end
  end

  @doc """
  Enqueues a `PythonWorker` job with the given args (e.g. `%{"name" => "David"}`).
  """
  def enqueue(args) when is_map(args) do
    args
    |> new()
    |> Oban.insert()
  end
end
