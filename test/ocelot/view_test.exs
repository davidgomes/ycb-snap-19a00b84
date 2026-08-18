defmodule Ocelot.ViewTest do
  use ExUnit.Case, async: true

  defp assigns(overrides \\ %{}) do
    Map.merge(
      %{
        jobs: [],
        counts: Map.new(Ocelot.Jobs.states(), &{&1, 0}),
        state: nil,
        base_path: "/"
      },
      overrides
    )
  end

  test "renders an empty state when there are no jobs" do
    html = Ocelot.View.render(assigns())

    assert html =~ "No jobs found."
    assert html =~ "Ocelot"
  end

  test "renders a row per job" do
    job = %Oban.Job{
      id: 1,
      state: "available",
      queue: "default",
      worker: "MyApp.Worker",
      attempt: 0,
      max_attempts: 20,
      inserted_at: ~N[2024-01-01 00:00:00]
    }

    html = Ocelot.View.render(assigns(%{jobs: [job]}))

    assert html =~ "MyApp.Worker"
    assert html =~ "0/20"
    assert html =~ "2024-01-01 00:00:00"
  end

  test "escapes job values" do
    job = %Oban.Job{
      id: 1,
      state: "available",
      queue: "default",
      worker: "<script>alert(1)</script>",
      attempt: 0,
      max_attempts: 20,
      inserted_at: ~N[2024-01-01 00:00:00]
    }

    html = Ocelot.View.render(assigns(%{jobs: [job]}))

    refute html =~ "<script>alert(1)</script>"
    assert html =~ "&lt;script&gt;"
  end

  test "marks the selected state filter as active" do
    html = Ocelot.View.render(assigns(%{state: "completed", base_path: "/oban"}))

    assert html =~ ~s(<a class="active" href="/oban?state=completed")
  end
end
