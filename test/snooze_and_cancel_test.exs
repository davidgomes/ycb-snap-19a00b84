# SPDX-FileCopyrightText: 2023 ash_oban contributors <https://github.com/ash-project/ash_oban/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshOban.SnoozeAndCancelTest do
  use ExUnit.Case, async: false

  use Oban.Testing, repo: AshOban.Test.Repo, prefix: "private"

  defmodule TestDomain do
    @moduledoc false
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      resource AshOban.SnoozeAndCancelTest.Snoozeable
    end
  end

  defmodule ProcessAtomically do
    @moduledoc false
    use Ash.Resource.Change

    require Ash.Expr

    def change(changeset, _opts, _context) do
      if Process.get(:snooze_and_cancel_test) == :snooze do
        Ash.Changeset.add_error(changeset, AshOban.snooze(60))
      else
        Ash.Changeset.change_attribute(changeset, :processed, true)
      end
    end

    def atomic(_changeset, _opts, _context) do
      if Process.get(:snooze_and_cancel_test) == :snooze do
        {:error, AshOban.snooze(60)}
      else
        {:atomic, %{processed: Ash.Expr.expr(true)}}
      end
    end
  end

  defmodule Snoozeable do
    @moduledoc false
    use Ash.Resource,
      domain: AshOban.SnoozeAndCancelTest.TestDomain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshOban]

    oban do
      triggers do
        trigger :process do
          action :process
          where expr(processed != true)
          scheduler_cron false
          queue :snooze_and_cancel
          max_attempts 2
          worker_module_name AshOban.SnoozeAndCancelTest.Snoozeable.Worker.Process
        end

        trigger :process_atomically do
          action :process_atomically
          where expr(processed != true)
          scheduler_cron false
          queue :snooze_and_cancel
          max_attempts 2
          worker_module_name AshOban.SnoozeAndCancelTest.Snoozeable.Worker.ProcessAtomically
        end

        trigger :process_generic do
          action :say_hello
          scheduler_cron false
          queue :snooze_and_cancel
          max_attempts 2
          worker_module_name AshOban.SnoozeAndCancelTest.Snoozeable.Worker.ProcessGeneric
        end

        trigger :process_with_on_error do
          action :process
          where expr(processed != true)
          scheduler_cron false
          queue :snooze_and_cancel
          on_error :mark_errored
          worker_module_name AshOban.SnoozeAndCancelTest.Snoozeable.Worker.ProcessWithOnError
        end
      end

      scheduled_actions do
        schedule :scheduled_hello, "0 0 1 1 *" do
          action :say_hello
          queue :snooze_and_cancel
          worker_module_name AshOban.SnoozeAndCancelTest.Snoozeable.ActionWorker.ScheduledHello
        end
      end
    end

    actions do
      defaults create: []

      read :read do
        primary? true
        pagination keyset?: true
      end

      update :process do
        require_atomic? false

        change fn changeset, _context ->
          case Process.get(:snooze_and_cancel_test) do
            :snooze -> Ash.Changeset.add_error(changeset, AshOban.snooze(60))
            :cancel -> Ash.Changeset.add_error(changeset, AshOban.cancel("no longer relevant"))
            :raise -> raise AshOban.Errors.Snooze, seconds: 30
            :error -> Ash.Changeset.add_error(changeset, "something went wrong")
            _ -> Ash.Changeset.change_attribute(changeset, :processed, true)
          end
        end
      end

      update :process_atomically do
        change AshOban.SnoozeAndCancelTest.ProcessAtomically
      end

      update :mark_errored do
        require_atomic? false
        argument :error, :term
        change set_attribute(:errored, true)
      end

      action :say_hello, :string do
        run fn _input, _context ->
          case Process.get(:snooze_and_cancel_test) do
            :snooze -> {:error, AshOban.snooze(60)}
            :cancel -> {:error, AshOban.cancel(:not_needed)}
            _ -> {:ok, "hello"}
          end
        end
      end
    end

    attributes do
      uuid_primary_key :id
      attribute :processed, :boolean, default: false, allow_nil?: false, public?: true
      attribute :errored, :boolean, default: false, allow_nil?: false, public?: true
      timestamps()
    end

    ets do
      private? true
    end
  end

  setup_all do
    AshOban.Test.Repo.start_link()
    Oban.start_link(AshOban.config([TestDomain], Application.get_env(:ash_oban, :oban)))
    :ok
  end

  setup do
    Oban.delete_all_jobs(Oban.Job)

    on_exit(fn -> Process.delete(:snooze_and_cancel_test) end)

    :ok
  end

  defp create_record do
    Snoozeable
    |> Ash.Changeset.for_create(:create, %{})
    |> Ash.create!()
  end

  defp drain do
    Oban.drain_queue(queue: :snooze_and_cancel)
  end

  describe "AshOban.snooze/1" do
    test "snoozes the job when added as an error by an action" do
      record = create_record()
      Process.put(:snooze_and_cancel_test, :snooze)

      AshOban.run_trigger(record, :process)

      assert %{snoozed: 1, failure: 0, success: 0} = drain()

      refute Ash.reload!(record).processed
    end

    test "snoozes the job when raised by an action" do
      record = create_record()
      Process.put(:snooze_and_cancel_test, :raise)

      AshOban.run_trigger(record, :process)

      assert %{snoozed: 1, failure: 0} = drain()
    end

    test "snoozes the job when the action is run atomically" do
      record = create_record()
      Process.put(:snooze_and_cancel_test, :snooze)

      AshOban.run_trigger(record, :process_atomically)

      assert %{snoozed: 1, failure: 0} = drain()

      refute Ash.reload!(record).processed
    end

    test "snoozes the job when returned by a generic action" do
      record = create_record()
      Process.put(:snooze_and_cancel_test, :snooze)

      AshOban.run_trigger(record, :process_generic)

      assert %{snoozed: 1, failure: 0} = drain()
    end

    test "snoozes the job when returned by a scheduled action" do
      Process.put(:snooze_and_cancel_test, :snooze)

      AshOban.schedule(Snoozeable, :scheduled_hello)

      assert %{snoozed: 1, failure: 0} = drain()
    end

    test "takes precedence over the on_error action" do
      record = create_record()
      Process.put(:snooze_and_cancel_test, :snooze)

      AshOban.run_trigger(record, :process_with_on_error)

      assert %{snoozed: 1, failure: 0} = drain()

      refute Ash.reload!(record).errored
    end

    test "the on_error action still runs for other errors" do
      record = create_record()
      Process.put(:snooze_and_cancel_test, :error)

      AshOban.run_trigger(record, :process_with_on_error)

      assert %{snoozed: 0} = drain()

      assert Ash.reload!(record).errored
    end
  end

  describe "AshOban.cancel/1" do
    test "cancels the job when added as an error by an action" do
      record = create_record()
      Process.put(:snooze_and_cancel_test, :cancel)

      AshOban.run_trigger(record, :process)

      assert %{cancelled: 1, failure: 0, success: 0} = drain()

      refute Ash.reload!(record).processed
    end

    test "cancels the job when returned by a generic action" do
      record = create_record()
      Process.put(:snooze_and_cancel_test, :cancel)

      AshOban.run_trigger(record, :process_generic)

      assert %{cancelled: 1, failure: 0} = drain()
    end

    test "cancels the job when returned by a scheduled action" do
      Process.put(:snooze_and_cancel_test, :cancel)

      AshOban.schedule(Snoozeable, :scheduled_hello)

      assert %{cancelled: 1, failure: 0} = drain()
    end
  end

  describe "actions that neither snooze nor cancel" do
    test "process the record as usual" do
      record = create_record()

      AshOban.run_trigger(record, :process)

      assert %{success: 1, snoozed: 0, cancelled: 0} = drain()

      assert Ash.reload!(record).processed
    end
  end
end
