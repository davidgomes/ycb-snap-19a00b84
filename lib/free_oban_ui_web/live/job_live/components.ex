defmodule FreeObanUiWeb.JobLive.Components do
  @moduledoc """
  Components and helpers shared by the job LiveViews.
  """
  use FreeObanUiWeb, :html

  alias FreeObanUi.Jobs
  alias Oban.Job

  @doc """
  Renders a job state as a colored badge.
  """
  attr :state, :string, required: true

  def state_badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center rounded-full px-2 text-xs font-medium leading-5 ring-1 ring-inset",
      state_classes(@state)
    ]}>
      <%= @state %>
    </span>
    """
  end

  defp state_classes("executing"), do: "bg-blue-50 text-blue-700 ring-blue-600/20"
  defp state_classes("available"), do: "bg-sky-50 text-sky-700 ring-sky-600/20"
  defp state_classes("scheduled"), do: "bg-violet-50 text-violet-700 ring-violet-600/20"
  defp state_classes("retryable"), do: "bg-amber-50 text-amber-700 ring-amber-600/20"
  defp state_classes("cancelled"), do: "bg-zinc-100 text-zinc-600 ring-zinc-500/20"
  defp state_classes("discarded"), do: "bg-rose-50 text-rose-700 ring-rose-600/20"
  defp state_classes("completed"), do: "bg-emerald-50 text-emerald-700 ring-emerald-600/20"
  defp state_classes(_state), do: "bg-zinc-50 text-zinc-600 ring-zinc-500/20"

  @doc """
  Renders the buttons for the actions allowed in the job's current state.
  """
  attr :job, Job, required: true

  def job_actions(assigns) do
    ~H"""
    <span class="inline-flex items-center gap-3">
      <button
        :if={Jobs.can_retry?(@job)}
        type="button"
        phx-click="retry"
        phx-value-id={@job.id}
        class="font-semibold text-zinc-900 hover:text-zinc-600"
      >
        <%= if @job.state == "scheduled", do: "Run now", else: "Retry" %>
      </button>
      <button
        :if={Jobs.can_cancel?(@job)}
        type="button"
        phx-click="cancel"
        phx-value-id={@job.id}
        data-confirm={"Cancel job ##{@job.id}?"}
        class="font-semibold text-zinc-900 hover:text-zinc-600"
      >
        Cancel
      </button>
      <button
        :if={Jobs.can_delete?(@job)}
        type="button"
        phx-click="delete"
        phx-value-id={@job.id}
        data-confirm={"Delete job ##{@job.id}? This cannot be undone."}
        class="font-semibold text-rose-600 hover:text-rose-500"
      >
        Delete
      </button>
    </span>
    """
  end

  @doc """
  Renders a timestamp relative to `now`, with the exact time on hover.
  """
  attr :at, DateTime, default: nil
  attr :now, DateTime, required: true

  def relative_time(%{at: nil} = assigns) do
    ~H"""
    <span class="text-zinc-400">&mdash;</span>
    """
  end

  def relative_time(assigns) do
    ~H"""
    <time datetime={DateTime.to_iso8601(@at)} title={format_datetime(@at)}>
      <%= format_relative(@at, @now) %>
    </time>
    """
  end

  defp format_relative(at, now) do
    diff = DateTime.diff(at, now)
    seconds = abs(diff)

    amount =
      cond do
        seconds < 60 -> "#{seconds}s"
        seconds < 3600 -> "#{div(seconds, 60)}m"
        seconds < 86_400 -> "#{div(seconds, 3600)}h"
        true -> "#{div(seconds, 86_400)}d"
      end

    if diff > 0, do: "in #{amount}", else: "#{amount} ago"
  end

  @doc """
  Formats a timestamp as an absolute UTC time.
  """
  def format_datetime(%DateTime{} = at), do: Calendar.strftime(at, "%Y-%m-%d %H:%M:%S UTC")

  @doc """
  Returns the timestamp most relevant to the job's current state.
  """
  def state_timestamp(%Job{state: "executing"} = job), do: job.attempted_at
  def state_timestamp(%Job{state: "completed"} = job), do: job.completed_at
  def state_timestamp(%Job{state: "cancelled"} = job), do: job.cancelled_at
  def state_timestamp(%Job{state: "discarded"} = job), do: job.discarded_at
  def state_timestamp(%Job{} = job), do: job.scheduled_at

  @doc """
  Runs a job action triggered by `job_actions/1` and puts a flash describing the outcome.

  Returns `{:ok, socket}` when the action was applied and `{:error, socket}` otherwise.
  """
  def apply_action(socket, action, id) when action in ~w(retry cancel delete) do
    case Jobs.get_job(id) do
      nil ->
        {:error, Phoenix.LiveView.put_flash(socket, :error, "Job ##{id} no longer exists")}

      job ->
        case run_action(action, job) do
          :ok ->
            {:ok, Phoenix.LiveView.put_flash(socket, :info, success_message(action, job))}

          {:error, :invalid_state} ->
            message = "Job ##{job.id} can't be #{past_tense(action)} while #{job.state}"
            {:error, Phoenix.LiveView.put_flash(socket, :error, message)}
        end
    end
  end

  defp run_action("retry", job), do: Jobs.retry_job(job)
  defp run_action("cancel", job), do: Jobs.cancel_job(job)
  defp run_action("delete", job), do: Jobs.delete_job(job)

  defp success_message("retry", job), do: "Job ##{job.id} queued to run"
  defp success_message(action, job), do: "Job ##{job.id} #{past_tense(action)}"

  defp past_tense("retry"), do: "retried"
  defp past_tense("cancel"), do: "cancelled"
  defp past_tense("delete"), do: "deleted"
end
