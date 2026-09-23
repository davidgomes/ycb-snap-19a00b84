defmodule FreeObanUiWeb.JobComponents do
  @moduledoc """
  Components shared by the Oban job pages.
  """
  use Phoenix.Component

  @doc """
  Renders a colored badge for an Oban job state.
  """
  attr :state, :string, required: true

  def state_badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex rounded-full px-2 text-xs font-medium leading-5",
      state_color(@state)
    ]}>
      <%= @state %>
    </span>
    """
  end

  defp state_color("available"), do: "bg-sky-100 text-sky-800"
  defp state_color("scheduled"), do: "bg-indigo-100 text-indigo-800"
  defp state_color("executing"), do: "bg-amber-100 text-amber-800"
  defp state_color("retryable"), do: "bg-orange-100 text-orange-800"
  defp state_color("completed"), do: "bg-emerald-100 text-emerald-800"
  defp state_color("discarded"), do: "bg-rose-100 text-rose-800"
  defp state_color("cancelled"), do: "bg-zinc-200 text-zinc-700"
  defp state_color(_state), do: "bg-zinc-100 text-zinc-700"

  @doc """
  Formats a job timestamp for display.
  """
  def format_timestamp(nil), do: "—"
  def format_timestamp(%DateTime{} = at), do: Calendar.strftime(at, "%Y-%m-%d %H:%M:%S UTC")
end
