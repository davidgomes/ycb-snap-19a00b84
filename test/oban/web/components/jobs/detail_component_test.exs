defmodule Oban.Web.Jobs.DetailComponentTest do
  use Oban.Web.Case, async: true

  import Phoenix.LiveViewTest

  alias Oban.Web.Jobs.DetailComponent, as: Component

  defmodule CustomResolver do
    @behaviour Oban.Web.Resolver

    @impl Oban.Web.Resolver
    def format_job_args(_job), do: "ARGS REDACTED"
  end

  setup do
    Process.put(:routing, :nowhere)

    :ok
  end

  test "restricting action buttons based on job state" do
    job = %Oban.Job{id: 1, worker: "MyApp.Worker", args: %{}, state: "retryable"}

    html = render_component(Component, assigns(job), router: Router)
    # Retryable jobs can be cancelled
    assert html =~ ~s(phx-click="cancel")
    refute html =~ ~s(id="detail-cancel" type="button" disabled)

    # Available job can be cancelled
    job = %Oban.Job{id: 1, worker: "MyApp.Worker", args: %{}, state: "available"}
    html = render_component(Component, assigns(job), router: Router)
    assert html =~ ~s(phx-click="cancel")
    refute html =~ ~s(id="detail-cancel" type="button" disabled)
  end

  test "disabling actions based on job state" do
    now = DateTime.utc_now()
    scheduled_at = DateTime.add(now, -60, :second)

    job = %Oban.Job{
      id: 1,
      worker: "MyApp.Worker",
      args: %{},
      state: "executing",
      attempted_at: now,
      inserted_at: scheduled_at,
      scheduled_at: scheduled_at
    }

    html = render_component(Component, assigns(job), router: Router)

    # Executing jobs can be cancelled (not disabled)
    assert html =~ ~s(phx-click="cancel")
    refute html =~ ~s(id="detail-cancel" type="button" disabled)

    # Executing jobs cannot be deleted (button is disabled)
    assert html =~ ~s(id="detail-delete" type="button" disabled)
  end

  test "customizing args formatting with a resolver" do
    job = %Oban.Job{id: 1, worker: "MyApp.Worker", args: %{"secret" => "sauce"}}

    html = render_component(Component, assigns(job, resolver: CustomResolver), router: Router)

    assert html =~ "ARGS REDACTED"
  end

  test "displaying the deadline for a job awaiting a signal" do
    meta = %{"await_until" => "2099-01-01T00:00:00Z"}
    job = %Oban.Job{id: 1, worker: "MyApp.Worker", args: %{}, meta: meta}

    html = render_component(Component, assigns(job), router: Router)

    assert html =~ "Awaiting Signal"
    assert html =~ "2099-01-01T00:00:00Z"
    refute html =~ ~s(id="copy-signal")
  end

  test "displaying the decoded payload for a signaled job" do
    signal = Base.encode64(:erlang.term_to_binary(%{decision: "approved"}), padding: false)
    meta = %{"await_until" => "2099-01-01T00:00:00Z", "signal" => signal}
    job = %Oban.Job{id: 1, worker: "MyApp.Worker", args: %{}, meta: meta}

    html = render_component(Component, assigns(job), router: Router)

    assert html =~ "Received Signal"
    assert html =~ "approved"
    assert html =~ ~s(id="copy-signal")

    # The encoded value is hidden from the raw meta block
    refute html =~ signal
  end

  defp assigns(job, opts \\ []) do
    os_time = System.system_time(:second)

    [
      access: :all,
      diagnostics: nil,
      diagnostics_at: nil,
      history: [],
      id: :details,
      os_time: os_time,
      params: %{},
      resolver: nil
    ]
    |> Keyword.put(:job, job)
    |> Keyword.merge(opts)
  end
end
