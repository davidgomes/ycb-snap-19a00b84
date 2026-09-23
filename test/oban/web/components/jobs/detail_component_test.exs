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

  describe "awaitable signals" do
    defmodule SignalResolver do
      @behaviour Oban.Web.Resolver

      @impl Oban.Web.Resolver
      def format_signal(_signal, _job), do: "SIGNAL REDACTED"
    end

    test "omitting the signal section for jobs without signals" do
      job = %Oban.Job{id: 1, worker: "MyApp.Worker", args: %{}, meta: %{}}

      html = render_component(Component, assigns(job), router: Router)

      refute html =~ ~s(id="job-signal")
      refute html =~ ~s(label="Signal")
    end

    test "rendering a received signal payload" do
      signal = encode_term(%{decision: "approved"})
      job = %Oban.Job{id: 1, worker: "MyApp.Worker", args: %{}, meta: %{"signal" => signal}}

      html = render_component(Component, assigns(job), router: Router)

      assert html =~ ~s(id="job-signal")
      assert html =~ "Received Signal"
      assert html =~ ~s(id="copy-signal")
      assert html =~ "decision: &quot;approved&quot;"
      refute html =~ signal
    end

    test "rendering the awaiting state with a deadline" do
      os_time = System.system_time(:second)
      wait_until = (os_time + 1_800) * 1_000

      job = %Oban.Job{
        id: 1,
        worker: "MyApp.Worker",
        args: %{},
        meta: %{"wait_until" => wait_until}
      }

      html = render_component(Component, assigns(job, os_time: os_time), router: Router)

      assert html =~ "Awaiting Signal"
      assert html =~ "Deadline in 30m"
      refute html =~ ~s(id="copy-signal")
    end

    test "rendering the awaiting state without a deadline" do
      job = %Oban.Job{
        id: 1,
        worker: "MyApp.Worker",
        args: %{},
        meta: %{"wait_until" => "infinity"}
      }

      html = render_component(Component, assigns(job), router: Router)

      assert html =~ "Awaiting Signal"
      assert html =~ "No deadline"
    end

    test "customizing signal formatting with a resolver" do
      signal = encode_term(%{token: "secret"})
      job = %Oban.Job{id: 1, worker: "MyApp.Worker", args: %{}, meta: %{"signal" => signal}}

      html = render_component(Component, assigns(job, resolver: SignalResolver), router: Router)

      assert html =~ "SIGNAL REDACTED"
      refute html =~ "secret"
    end
  end

  defp encode_term(term) do
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
