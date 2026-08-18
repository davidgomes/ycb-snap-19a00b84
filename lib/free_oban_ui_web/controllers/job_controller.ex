defmodule FreeObanUiWeb.JobController do
  use FreeObanUiWeb, :controller

  alias FreeObanUi.Jobs

  def index(conn, params) do
    filters = Jobs.list(params)

    render(conn, :index,
      jobs: filters.jobs,
      selected_state: filters.state,
      selected_queue: filters.queue,
      states: Jobs.states(),
      queues: Jobs.queues(),
      counts: Jobs.counts(),
      page_title: "Oban Jobs"
    )
  end
end
