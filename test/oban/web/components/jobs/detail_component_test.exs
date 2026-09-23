defmodule Oban.Web.Jobs.DetailComponentTest do
  use Oban.Web.Case, async: true

  import Phoenix.LiveViewTest

  alias Oban.Web.Jobs.DetailComponent, as: Component

  defmodule CustomResolver do
    @behaviour Oban.Web.Resolver

    @impl Oban.Web.Resolver
    def format_job_args(_job), do: "ARGS REDACTED"

    @impl Oban.Web.Resolver
    def format_signal(_signal, _job), do: "SIGNAL REDACTED"
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

  describe "awaitable signals" do
    test "omitting the signal section for jobs without signals" do
      job = %Oban.Job{id: 1, worker: "MyApp.Worker", args: %{}, meta: %{}, state: "scheduled"}

      html = render_component(Component, assigns(job), router: Router)

      refute has_fragment?(html, "#job-signal")
    end

    test "displaying the deadline while a job is awaiting a signal" do
      os_time = System.system_time(:second)
      deadline = DateTime.from_unix!(os_time + 3 * 60 * 60)
      meta = %{"signal_deadline" => DateTime.to_iso8601(deadline)}
      job = %Oban.Job{id: 1, worker: "MyApp.Worker", args: %{}, meta: meta, state: "scheduled"}

      html = render_component(Component, assigns(job, os_time: os_time), router: Router)

      assert has_fragment?(html, "#job-signal")
      assert html =~ "Awaiting Signal"
      assert html =~ "Deadline #{deadline} (in 3h)"
      refute has_fragment?(html, "#copy-signal")
    end

    test "displaying an indefinite wait while a job is awaiting a signal" do
      meta = %{"signal_deadline" => "infinity"}
      job = %Oban.Job{id: 1, worker: "MyApp.Worker", args: %{}, meta: meta, state: "scheduled"}

      html = render_component(Component, assigns(job), router: Router)

      assert html =~ "Awaiting Signal"
      assert html =~ "waiting indefinitely"
    end

    test "omitting the awaiting state once a job is finished" do
      meta = %{"signal_deadline" => "infinity"}
      job = %Oban.Job{id: 1, worker: "MyApp.Worker", args: %{}, meta: meta, state: "cancelled"}

      html = render_component(Component, assigns(job), router: Router)

      refute has_fragment?(html, "#job-signal")
    end

    test "decoding and displaying a received signal" do
      signal = encode_signal(%{decision: "approved"})
      meta = %{"signal" => signal, "signal_deadline" => "infinity"}
      job = %Oban.Job{id: 1, worker: "MyApp.Worker", args: %{}, meta: meta, state: "available"}

      html = render_component(Component, assigns(job), router: Router)

      assert html =~ "Received Signal"
      refute html =~ "Awaiting Signal"
      assert has_fragment?(html, "#job-signal pre", ~s(%{decision: "approved"}))
      assert has_fragment?(html, "#copy-signal")
      refute html =~ signal
    end

    test "customizing signal formatting with a resolver" do
      meta = %{"signal" => encode_signal(%{decision: "approved"})}
      job = %Oban.Job{id: 1, worker: "MyApp.Worker", args: %{}, meta: meta, state: "completed"}

      html = render_component(Component, assigns(job, resolver: CustomResolver), router: Router)

      assert has_fragment?(html, "#job-signal pre", "SIGNAL REDACTED")
    end
  end

  defp encode_signal(payload) do
    payload
    |> :erlang.term_to_binary()
    |> Base.encode64(padding: false)
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
