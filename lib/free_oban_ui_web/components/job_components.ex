defmodule FreeObanUiWeb.JobComponents do
  @moduledoc false
  use FreeObanUiWeb, :html

  attr :state, :string, required: true

  def state_badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex rounded-full px-2 py-0.5 text-xs font-semibold",
      badge_class(@state)
    ]}>
      <%= @state %>
    </span>
    """
  end

  def format_dt(nil), do: "—"

  def format_dt(%DateTime{} = datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S")
  end

  def pretty_json(term) do
    Jason.encode!(term, pretty: true)
  end

  defp badge_class("available"), do: "bg-sky-100 text-sky-800"
  defp badge_class("scheduled"), do: "bg-indigo-100 text-indigo-800"
  defp badge_class("executing"), do: "bg-amber-100 text-amber-800"
  defp badge_class("retryable"), do: "bg-orange-100 text-orange-800"
  defp badge_class("completed"), do: "bg-emerald-100 text-emerald-800"
  defp badge_class("discarded"), do: "bg-rose-100 text-rose-800"
  defp badge_class("cancelled"), do: "bg-zinc-200 text-zinc-700"
  defp badge_class(_), do: "bg-zinc-100 text-zinc-700"
end
