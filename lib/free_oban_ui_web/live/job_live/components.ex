defmodule FreeObanUiWeb.JobLive.Components do
  @moduledoc """
  Components shared by the job LiveViews.
  """

  use Phoenix.Component

  attr :state, :string, required: true

  def state_badge(assigns) do
    ~H"""
    <span class={[
      "rounded-full px-2 py-0.5 text-xs font-semibold",
      state_class(@state)
    ]}>
      <%= @state %>
    </span>
    """
  end

  attr :at, :any, required: true

  def timestamp(%{at: nil} = assigns), do: ~H"-"

  def timestamp(assigns) do
    ~H"""
    <time datetime={to_iso8601(@at)}><%= Calendar.strftime(@at, "%Y-%m-%d %H:%M:%S") %></time>
    """
  end

  defp to_iso8601(%DateTime{} = at), do: DateTime.to_iso8601(at)
  defp to_iso8601(%NaiveDateTime{} = at), do: NaiveDateTime.to_iso8601(at)

  defp state_class("available"), do: "bg-sky-100 text-sky-800"
  defp state_class("scheduled"), do: "bg-indigo-100 text-indigo-800"
  defp state_class("executing"), do: "bg-amber-100 text-amber-800"
  defp state_class("retryable"), do: "bg-orange-100 text-orange-800"
  defp state_class("completed"), do: "bg-emerald-100 text-emerald-800"
  defp state_class("discarded"), do: "bg-rose-100 text-rose-800"
  defp state_class(_cancelled), do: "bg-zinc-200 text-zinc-700"
end
