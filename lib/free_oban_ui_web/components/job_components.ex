defmodule FreeObanUiWeb.JobComponents do
  @moduledoc """
  Components for rendering Oban jobs.
  """
  use Phoenix.Component

  @state_classes %{
    "executing" => "bg-blue-50 text-blue-700 ring-blue-600/20",
    "available" => "bg-teal-50 text-teal-700 ring-teal-600/20",
    "scheduled" => "bg-indigo-50 text-indigo-700 ring-indigo-600/20",
    "retryable" => "bg-amber-50 text-amber-700 ring-amber-600/20",
    "cancelled" => "bg-zinc-100 text-zinc-600 ring-zinc-500/20",
    "discarded" => "bg-rose-50 text-rose-700 ring-rose-600/20",
    "completed" => "bg-emerald-50 text-emerald-700 ring-emerald-600/20"
  }

  @doc """
  Renders a colored badge for a job state.
  """
  attr :state, :string, required: true

  def state_badge(assigns) do
    assigns = assign(assigns, :class, Map.get(@state_classes, assigns.state))

    ~H"""
    <span class={[
      "inline-flex items-center rounded-md px-2 py-0.5 text-xs font-medium ring-1 ring-inset",
      @class
    ]}>
      <%= @state %>
    </span>
    """
  end

  @doc """
  Renders a timestamp relative to now, with the absolute time as a tooltip.
  """
  attr :at, :any, required: true
  attr :now, DateTime, default: nil

  def relative_time(%{at: nil} = assigns) do
    ~H"""
    <span class="text-zinc-400">-</span>
    """
  end

  def relative_time(assigns) do
    ~H"""
    <time datetime={DateTime.to_iso8601(@at)} title={DateTime.to_iso8601(@at)}>
      <%= format_relative(@at, @now || DateTime.utc_now()) %>
    </time>
    """
  end

  @doc """
  Formats a datetime as a short relative duration, e.g. `"5m ago"` or `"in 2h"`.
  """
  def format_relative(%DateTime{} = at, %DateTime{} = now) do
    diff = DateTime.diff(now, at, :second)
    duration = format_duration(abs(diff))

    cond do
      duration == "now" -> "now"
      diff >= 0 -> "#{duration} ago"
      true -> "in #{duration}"
    end
  end

  defp format_duration(seconds) when seconds < 1, do: "now"
  defp format_duration(seconds) when seconds < 60, do: "#{seconds}s"
  defp format_duration(seconds) when seconds < 3_600, do: "#{div(seconds, 60)}m"
  defp format_duration(seconds) when seconds < 86_400, do: "#{div(seconds, 3_600)}h"
  defp format_duration(seconds), do: "#{div(seconds, 86_400)}d"

  @doc """
  Pretty-prints a JSON-encodable term.
  """
  def pretty_json(term), do: Jason.encode!(term, pretty: true)
end
