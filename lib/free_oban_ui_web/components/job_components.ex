defmodule FreeObanUiWeb.JobComponents do
  @moduledoc """
  Components and formatting helpers shared by the Oban jobs pages.
  """
  use Phoenix.Component

  alias Oban.Job

  @doc """
  Renders a colored badge for a job state.
  """
  attr :state, :string, required: true

  def state_badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium ring-1 ring-inset",
      state_color(@state)
    ]}>
      <%= @state %>
    </span>
    """
  end

  defp state_color("scheduled"), do: "bg-sky-50 text-sky-700 ring-sky-600/20"
  defp state_color("available"), do: "bg-indigo-50 text-indigo-700 ring-indigo-600/20"
  defp state_color("executing"), do: "bg-amber-50 text-amber-700 ring-amber-600/20"
  defp state_color("retryable"), do: "bg-orange-50 text-orange-700 ring-orange-600/20"
  defp state_color("completed"), do: "bg-emerald-50 text-emerald-700 ring-emerald-600/20"
  defp state_color("discarded"), do: "bg-rose-50 text-rose-700 ring-rose-600/20"
  defp state_color(_state), do: "bg-zinc-50 text-zinc-600 ring-zinc-500/20"

  @doc """
  Renders the timestamp most relevant to a job's current state.
  """
  attr :job, Job, required: true

  def job_timestamp(assigns) do
    {label, at} = relevant_timestamp(assigns.job)
    assigns = assign(assigns, label: label, at: at)

    ~H"""
    <span class="text-zinc-500"><%= @label %></span> <%= format_timestamp(@at) %>
    """
  end

  defp relevant_timestamp(%Job{state: "executing"} = job), do: {"attempted", job.attempted_at}
  defp relevant_timestamp(%Job{state: "completed"} = job), do: {"completed", job.completed_at}
  defp relevant_timestamp(%Job{state: "discarded"} = job), do: {"discarded", job.discarded_at}
  defp relevant_timestamp(%Job{state: "cancelled"} = job), do: {"cancelled", job.cancelled_at}
  defp relevant_timestamp(%Job{} = job), do: {"scheduled", job.scheduled_at}

  def format_timestamp(nil), do: "—"
  def format_timestamp(%DateTime{} = at), do: Calendar.strftime(at, "%Y-%m-%d %H:%M:%S UTC")

  def format_json(term, opts \\ []), do: Jason.encode!(term, opts)
end
