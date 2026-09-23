defmodule ObanChoreWeb.DashboardLiveTest do
  use ObanChore.ObanCase, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  @endpoint ObanChore.Test.Endpoint

  setup do
    start_oban!([Chores.Greeter, Chores.Parked, Chores.UniqueParked])
    {:ok, conn: build_conn()}
  end

  describe "mount" do
    test "lists the registered chores", %{conn: conn} do
      {:ok, view, html} = live(conn, "/chores")

      assert html =~ "No chore selected"
      assert has_element?(view, nav(Chores.Greeter), "Greeter")
      assert has_element?(view, nav(Chores.Parked), "Parked")
      assert has_element?(view, nav(Chores.UniqueParked), "Unique Parked")
    end

    test "shows active jobs and their counts", %{conn: conn} do
      %{id: job_id} = insert_job!(Chores.Parked, %{user_id: 1})

      {:ok, view, _html} = live(conn, "/chores")

      assert has_element?(view, "#{nav(Chores.Parked)} .oc-badge", "1")
      refute has_element?(view, "#{nav(Chores.Greeter)} .oc-badge")

      view |> element(nav(Chores.Parked)) |> render_click()
      view |> element(tab(job_id), "Job ##{job_id}") |> render_click()

      assert has_element?(view, "#{job(job_id)}.oc-block")
      assert has_element?(view, "#{job(job_id)} .oc-badge", "Available")
      assert has_element?(view, "#{chore(Chores.Parked)}.oc-hidden")

      view |> element("button[phx-value-tab='new']") |> render_click()

      assert has_element?(view, "#{chore(Chores.Parked)}.oc-block")
      assert has_element?(view, "#{job(job_id)}.oc-hidden")
    end

    test "updates counts from broadcasts", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chores")

      Phoenix.PubSub.broadcast(
        pubsub(),
        "oban_chore:counts",
        {:oban_chore_count, Chores.Greeter, 3}
      )

      assert has_element?(view, "#{nav(Chores.Greeter)} .oc-badge", "3")
    end
  end

  describe "chore form" do
    test "selecting a chore shows its form", %{conn: conn} do
      view = select_chore(conn, Chores.Greeter)

      assert has_element?(view, "#{nav(Chores.Greeter)}.oc-nav-item--active")
      assert has_element?(view, ".oc-subtitle", "Says hello to someone.")
      assert has_element?(view, "#{chore(Chores.Greeter)}.oc-block")
      assert has_element?(view, "#{chore(Chores.Parked)}.oc-hidden")
      assert has_element?(view, "#{chore(Chores.Greeter)} label", "Name")
      assert has_element?(view, "#{chore(Chores.Greeter)} input[name='args[times]'][value='1']")

      view |> element(nav(Chores.Parked)) |> render_click()

      assert has_element?(view, ".oc-subtitle", "Configure and execute this chore.")
      assert has_element?(view, "#{chore(Chores.Parked)}.oc-block")
    end

    test "validates on change", %{conn: conn} do
      view = select_chore(conn, Chores.Greeter)

      view
      |> form(chore_form(Chores.Greeter), args: %{name: "Ada", times: "0"})
      |> render_change()

      assert has_element?(view, chore(Chores.Greeter), "must be greater than 0")
    end

    test "doesn't enqueue invalid args", %{conn: conn} do
      view = select_chore(conn, Chores.Greeter)

      submit(view, Chores.Greeter, %{name: "", times: "1"})

      assert has_element?(view, chore(Chores.Greeter), "can't be blank")
      assert jobs_for(Chores.Greeter) == []
    end
  end

  describe "execution" do
    test "enqueues the job and streams its progress", %{conn: conn} do
      view = select_chore(conn, Chores.Greeter)

      submit(view, Chores.Greeter, %{name: "Ada", times: "2"})

      assert [%Oban.Job{id: job_id, args: %{"name" => "Ada", "times" => 2}}] =
               jobs_for(Chores.Greeter)

      assert has_element?(view, "#{tab(job_id)}.oc-tab-item--active")
      assert has_element?(view, "#{job(job_id)}.oc-block")
      assert has_element?(view, "#{job(job_id)} .oc-job-arg-value", ~s("Ada"))

      assert {^job_id, pid} = await_job_started()
      release_job(pid)

      assert_eventually(fn -> has_element?(view, "#{job(job_id)} .oc-badge", "Completed") end)

      logs = view |> element(job(job_id)) |> render() |> LazyHTML.from_fragment()

      assert logs |> LazyHTML.query(".oc-log-content") |> Enum.map(&LazyHTML.text/1) ==
               ["Hello, Ada!", "Hello, Ada!"]
    end

    test "warns about a duplicate active job and can be cancelled", %{conn: conn} do
      insert_job!(Chores.Parked, %{user_id: 7})
      view = select_chore(conn, Chores.Parked)

      submit(view, Chores.Parked, %{user_id: "7"})

      assert has_element?(view, "#{chore(Chores.Parked)} .oc-alert-warning")

      view |> element("#{chore(Chores.Parked)} button", "Cancel") |> render_click()

      refute has_element?(view, "#{chore(Chores.Parked)} .oc-alert-warning")
      assert length(jobs_for(Chores.Parked)) == 1
    end

    test "confirming a duplicate is blocked by unique execution", %{conn: conn} do
      %{id: job_id} = insert_job!(Chores.Parked, %{user_id: 7})
      view = select_chore(conn, Chores.Parked)

      submit(view, Chores.Parked, %{user_id: "7"})
      confirm_duplicate(view, Chores.Parked)

      assert [%Oban.Job{id: ^job_id}] = jobs_for(Chores.Parked)
      assert has_element?(view, "#{tab(job_id)}.oc-tab-item--active")
    end

    test "confirming a duplicate enqueues it when unique execution is off", %{conn: conn} do
      insert_job!(Chores.Parked, %{user_id: 7})
      view = select_chore(conn, Chores.Parked)

      view |> element(unique_toggle(Chores.Parked)) |> render_click()
      submit(view, Chores.Parked, %{user_id: "7"})
      confirm_duplicate(view, Chores.Parked)

      assert [%{id: first_id, args: %{"user_id" => 7}}, %{id: second_id, args: %{"user_id" => 7}}] =
               jobs_for(Chores.Parked)

      assert has_element?(view, "#{tab(second_id)}.oc-tab-item--active")
      assert has_element?(view, tab(first_id))
    end

    test "unique execution without a duplicate enqueues a new job", %{conn: conn} do
      insert_job!(Chores.Parked, %{user_id: 7})
      view = select_chore(conn, Chores.Parked)

      submit(view, Chores.Parked, %{user_id: "8"})

      refute has_element?(view, "#{chore(Chores.Parked)} .oc-alert-warning")
      assert [_existing, %{id: new_id, args: %{"user_id" => 8}}] = jobs_for(Chores.Parked)
      assert has_element?(view, "#{tab(new_id)}.oc-tab-item--active")
    end

    test "workers with their own unique options enforce it", %{conn: conn} do
      %{id: job_id} = insert_job!(Chores.UniqueParked, %{account_id: 7})
      view = select_chore(conn, Chores.UniqueParked)

      assert has_element?(view, "#{unique_toggle(Chores.UniqueParked)}[disabled]")

      submit(view, Chores.UniqueParked, %{account_id: "7"})
      confirm_duplicate(view, Chores.UniqueParked)

      assert [%Oban.Job{id: ^job_id}] = jobs_for(Chores.UniqueParked)
      assert has_element?(view, "#{tab(job_id)}.oc-tab-item--active")
    end
  end

  defp nav(module), do: "button[phx-value-module='#{module}']"
  defp tab(job_id), do: "button[phx-value-tab='job_#{job_id}']"
  defp chore(module), do: "[data-chore='#{inspect(module)}']"
  defp chore_form(module), do: "#{chore(module)} form"
  defp job(job_id), do: "[data-job='#{job_id}']"
  defp unique_toggle(module), do: "#{chore(module)} input[type='checkbox'][id='unique-#{module}']"

  defp select_chore(conn, module) do
    {:ok, view, _html} = live(conn, "/chores")
    view |> element(nav(module)) |> render_click()
    view
  end

  defp submit(view, module, args) do
    view |> form(chore_form(module), args: args) |> render_submit()
  end

  defp confirm_duplicate(view, module) do
    view |> element("#{chore(module)} button", "Confirm anyway") |> render_click()
  end

  defp assert_eventually(fun, attempts \\ 50) do
    cond do
      fun.() ->
        :ok

      attempts == 0 ->
        flunk("condition was not met in time")

      true ->
        Process.sleep(20)
        assert_eventually(fun, attempts - 1)
    end
  end
end
