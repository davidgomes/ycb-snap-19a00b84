defmodule FreeObanUiWeb.JobHTML do
  use FreeObanUiWeb, :html

  embed_templates "job_html/*"

  def state_class("completed"), do: "bg-emerald-50 text-emerald-700 ring-emerald-600/20"
  def state_class("executing"), do: "bg-blue-50 text-blue-700 ring-blue-600/20"
  def state_class("discarded"), do: "bg-red-50 text-red-700 ring-red-600/20"
  def state_class("cancelled"), do: "bg-zinc-100 text-zinc-600 ring-zinc-500/20"
  def state_class(_state), do: "bg-amber-50 text-amber-700 ring-amber-600/20"

  def format_time(nil), do: "—"

  def format_time(datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S UTC")
  end
end
