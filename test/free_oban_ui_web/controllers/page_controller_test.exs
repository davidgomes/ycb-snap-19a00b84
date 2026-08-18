defmodule FreeObanUiWeb.JobControllerTest do
  use FreeObanUiWeb.ConnCase

  defmodule ExampleWorker do
    use Oban.Worker, queue: :mailers

    @impl Oban.Worker
    def perform(_job), do: :ok
  end

  test "GET / lists Oban jobs", %{conn: conn} do
    job = Oban.insert!(ExampleWorker.new(%{"account_id" => 123}))

    conn = get(conn, ~p"/")
    response = html_response(conn, 200)

    assert response =~ "Oban Jobs"
    assert response =~ inspect(ExampleWorker)
    assert response =~ job.queue
    assert response =~ "available"
  end

  test "GET / filters jobs by state and queue", %{conn: conn} do
    Oban.insert!(ExampleWorker.new(%{}))

    conn = get(conn, ~p"/?state=completed&queue=mailers")
    response = html_response(conn, 200)

    assert response =~ "No jobs match these filters."
  end
end
