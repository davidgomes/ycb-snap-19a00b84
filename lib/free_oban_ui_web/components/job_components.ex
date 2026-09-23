defmodule FreeObanUiWeb.JobComponents do
  @moduledoc """
  Components and helpers for rendering Oban jobs.
  """
  use Phoenix.Component

  alias Oban.Job

  @doc """
  Renders a pill with the job's state.
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

  @doc """
  Renders a time relative to now, such as `3m ago` or `in 10s`, with the
  absolute time as a tooltip.
  """
  attr :at, DateTime, default: nil

  def relative_time(%{at: nil} = assigns) do
    ~H"""
    <span class="text-zinc-400">&mdash;</span>
    """
  end

  def relative_time(assigns) do
    ~H"""
    <time datetime={DateTime.to_iso8601(@at)} title={format_datetime(@at)}>
      <%= format_relative(@at) %>
    </time>
    """
  end

  @doc """
  Renders an absolute time followed by the time relative to now.
  """
  attr :at, DateTime, default: nil

  def timestamp(%{at: nil} = assigns) do
    ~H"""
    <span class="text-zinc-400">&mdash;</span>
    """
  end

  def timestamp(assigns) do
    ~H"""
    <%= format_datetime(@at) %>
    <span class="text-zinc-500">(<%= format_relative(@at) %>)</span>
    """
  end

  @doc """
  Returns the timestamp that best describes the job's current state, such as
  when a scheduled job will run or when a completed job finished.
  """
  def state_timestamp(%Job{state: "executing"} = job), do: job.attempted_at
  def state_timestamp(%Job{state: "completed"} = job), do: job.completed_at
  def state_timestamp(%Job{state: "cancelled"} = job), do: job.cancelled_at
  def state_timestamp(%Job{state: "discarded"} = job), do: job.discarded_at
  def state_timestamp(%Job{} = job), do: job.scheduled_at

  @doc """
  Formats a datetime as `YYYY-MM-DD HH:MM:SS UTC`.
  """
  def format_datetime(%DateTime{time_zone: "Etc/UTC"} = at) do
    Calendar.strftime(at, "%Y-%m-%d %H:%M:%S UTC")
  end

  @doc """
  Formats the distance between a datetime and `now`, such as `3m ago` or `in 10s`.
  """
  def format_relative(%DateTime{} = at, now \\ DateTime.utc_now()) do
    case DateTime.diff(at, now) do
      0 -> "now"
      diff when diff > 0 -> "in " <> format_duration(diff)
      diff -> format_duration(-diff) <> " ago"
    end
  end

  @doc """
  Encodes a term as pretty-printed JSON.
  """
  def format_json(term), do: Jason.encode!(term, pretty: true)

  defp format_duration(seconds) when seconds < 60, do: "#{seconds}s"
  defp format_duration(seconds) when seconds < 3_600, do: "#{div(seconds, 60)}m"
  defp format_duration(seconds) when seconds < 86_400, do: "#{div(seconds, 3_600)}h"
  defp format_duration(seconds), do: "#{div(seconds, 86_400)}d"

  defp state_color("scheduled"), do: "bg-sky-50 text-sky-700 ring-sky-600/20"
  defp state_color("available"), do: "bg-indigo-50 text-indigo-700 ring-indigo-600/20"
  defp state_color("executing"), do: "bg-amber-50 text-amber-700 ring-amber-600/20"
  defp state_color("retryable"), do: "bg-orange-50 text-orange-700 ring-orange-600/20"
  defp state_color("completed"), do: "bg-emerald-50 text-emerald-700 ring-emerald-600/20"
  defp state_color("discarded"), do: "bg-rose-50 text-rose-700 ring-rose-600/20"
  defp state_color(_state), do: "bg-zinc-50 text-zinc-600 ring-zinc-500/20"
end
