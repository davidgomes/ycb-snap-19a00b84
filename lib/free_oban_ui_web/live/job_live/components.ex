defmodule FreeObanUiWeb.JobLive.Components do
  @moduledoc """
  Components shared by the job LiveViews.
  """

  use Phoenix.Component

  attr :state, :string, required: true

  def state_badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center rounded-full px-2 text-xs font-medium leading-6",
      state_class(@state)
    ]}>
      <%= @state %>
    </span>
    """
  end

  defp state_class("available"), do: "bg-sky-100 text-sky-800"
  defp state_class("scheduled"), do: "bg-indigo-100 text-indigo-800"
  defp state_class("executing"), do: "bg-amber-100 text-amber-800"
  defp state_class("retryable"), do: "bg-orange-100 text-orange-800"
  defp state_class("completed"), do: "bg-emerald-100 text-emerald-800"
  defp state_class("discarded"), do: "bg-rose-100 text-rose-800"
  defp state_class("cancelled"), do: "bg-zinc-200 text-zinc-700"
  defp state_class(_state), do: "bg-zinc-100 text-zinc-700"

  @doc """
  Formats a job timestamp relative to now, e.g. "5s ago" or "in 2m".
  """
  def relative_time(nil), do: "-"

  def relative_time(%DateTime{} = datetime) do
    diff = DateTime.diff(DateTime.utc_now(), datetime)

    if diff >= 0, do: "#{humanize(diff)} ago", else: "in #{humanize(-diff)}"
  end

  def absolute_time(nil), do: "-"

  def absolute_time(%DateTime{} = datetime),
    do: Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S UTC")

  @doc """
  The most relevant timestamp for a job in its current state.
  """
  def state_time(%Oban.Job{state: state} = job) do
    case state do
      "completed" -> job.completed_at
      "cancelled" -> job.cancelled_at
      "discarded" -> job.discarded_at
      "executing" -> job.attempted_at
      _ -> job.scheduled_at
    end
  end

  defp humanize(seconds) when seconds < 60, do: "#{seconds}s"
  defp humanize(seconds) when seconds < 3_600, do: "#{div(seconds, 60)}m"
  defp humanize(seconds) when seconds < 86_400, do: "#{div(seconds, 3_600)}h"
  defp humanize(seconds), do: "#{div(seconds, 86_400)}d"
end
