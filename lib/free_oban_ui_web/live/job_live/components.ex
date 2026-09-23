defmodule FreeObanUiWeb.JobLive.Components do
  @moduledoc """
  Components and formatting helpers shared by the job LiveViews.
  """
  use Phoenix.Component

  @doc """
  Renders a job state as a colored badge.
  """
  attr :state, :string, required: true

  def state_badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center rounded-md px-2 py-0.5 text-xs font-medium ring-1 ring-inset",
      state_classes(@state)
    ]}>
      <%= @state %>
    </span>
    """
  end

  defp state_classes("executing"), do: "bg-sky-50 text-sky-700 ring-sky-600/20"
  defp state_classes("available"), do: "bg-indigo-50 text-indigo-700 ring-indigo-600/20"
  defp state_classes("scheduled"), do: "bg-violet-50 text-violet-700 ring-violet-600/20"
  defp state_classes("retryable"), do: "bg-amber-50 text-amber-800 ring-amber-600/20"
  defp state_classes("cancelled"), do: "bg-zinc-50 text-zinc-600 ring-zinc-500/20"
  defp state_classes("discarded"), do: "bg-rose-50 text-rose-700 ring-rose-600/20"
  defp state_classes("completed"), do: "bg-emerald-50 text-emerald-700 ring-emerald-600/20"
  defp state_classes(_state), do: "bg-zinc-50 text-zinc-600 ring-zinc-500/20"

  @doc """
  Formats a datetime, or an ISO 8601 string such as the `"at"` of job errors, in UTC.
  """
  def format_datetime(nil), do: "—"

  def format_datetime(%DateTime{} = datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S UTC")
  end

  def format_datetime(iso8601) when is_binary(iso8601) do
    case DateTime.from_iso8601(iso8601) do
      {:ok, datetime, _offset} -> format_datetime(datetime)
      {:error, _reason} -> iso8601
    end
  end

  @doc """
  Encodes a job's args or meta as JSON.
  """
  def format_json(term, opts \\ []), do: Jason.encode!(term, opts)
end
