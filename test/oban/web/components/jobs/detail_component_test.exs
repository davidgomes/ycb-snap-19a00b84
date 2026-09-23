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

  describe "signals" do
    test "omitting the signal section without any signal meta" do
      job = %Oban.Job{id: 1, worker: "MyApp.Worker", args: %{}}

      html = render_component(Component, assigns(job), router: Router)

      refute html =~ "icon-signal"
      refute html =~ ~s(id="job-signal")
    end

    test "displaying the awaiting state with a deadline" do
      wait_until = System.system_time(:millisecond) + :timer.minutes(30)

      job = %Oban.Job{
        id: 1,
        worker: "MyApp.Worker",
        args: %{},
        meta: %{"wait_until" => wait_until}
      }

      html = render_component(Component, assigns(job), router: Router)

      assert html =~ "icon-signal"
      assert html =~ "Awaiting Signal"
      assert html =~ "Deadline in"
      refute html =~ ~s(id="copy-signal")
    end

    test "displaying the awaiting state without a deadline" do
      job = %Oban.Job{
        id: 1,
        worker: "MyApp.Worker",
        args: %{},
        meta: %{"wait_until" => "infinity"}
      }

      html = render_component(Component, assigns(job), router: Router)

      assert html =~ "Awaiting Signal"
      assert html =~ "Waiting indefinitely"
    end

    test "displaying a decoded payload once a signal is received" do
      signal = encode_signal(%{decision: "approved"})
      job = %Oban.Job{id: 1, worker: "MyApp.Worker", args: %{}, meta: %{"signal" => signal}}

      html = render_component(Component, assigns(job), router: Router)

      assert html =~ "icon-signal"
      assert html =~ "Received Signal"
      assert html =~ "decision: &quot;approved&quot;"
      assert html =~ ~s(id="copy-signal")
      refute html =~ signal
    end

    test "customizing signal formatting with a resolver" do
      signal = encode_signal(%{decision: "approved"})
      job = %Oban.Job{id: 1, worker: "MyApp.Worker", args: %{}, meta: %{"signal" => signal}}

      html = render_component(Component, assigns(job, resolver: CustomResolver), router: Router)

      assert html =~ "SIGNAL REDACTED"
    end
  end

  defp encode_signal(term) do
    term
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
