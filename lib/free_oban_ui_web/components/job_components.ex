defmodule FreeObanUiWeb.JobComponents do
  @moduledoc """
  Components shared by the Oban job pages.
  """

  use Phoenix.Component

  @state_classes %{
    "available" => "bg-sky-100 text-sky-800",
    "scheduled" => "bg-indigo-100 text-indigo-800",
    "executing" => "bg-amber-100 text-amber-800",
    "retryable" => "bg-orange-100 text-orange-800",
    "completed" => "bg-emerald-100 text-emerald-800",
    "discarded" => "bg-rose-100 text-rose-800",
    "cancelled" => "bg-zinc-200 text-zinc-700"
  }

  attr :state, :string, required: true

  def state_badge(assigns) do
    assigns = assign(assigns, :class, Map.get(@state_classes, assigns.state, "bg-zinc-100"))

    ~H"""
    <span class={["rounded-full px-2 py-0.5 text-xs font-medium", @class]}><%= @state %></span>
    """
  end

  def format_time(nil), do: "—"
  def format_time(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S UTC")

  def short_worker(worker), do: worker |> String.split(".") |> List.last()
end
