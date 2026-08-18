# SPDX-FileCopyrightText: 2023 ash_oban contributors <https://github.com/ash-project/ash_oban/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshOban.JobControlTest do
  use ExUnit.Case, async: true

  describe "job_control/1" do
    test "passes through results that are not job control errors" do
      assert :ok == AshOban.job_control(fn -> :ok end)
      assert {:ok, 1} == AshOban.job_control(fn -> {:ok, 1} end)

      assert {:error, :oops} == AshOban.job_control(fn -> {:error, :oops} end)
    end

    test "reraises errors that are not job control errors" do
      assert_raise RuntimeError, "oops", fn ->
        AshOban.job_control(fn -> raise "oops" end)
      end
    end

    test "raised job control errors are translated" do
      assert {:snooze, 60} ==
               AshOban.job_control(fn -> raise AshOban.Errors.SnoozeJob, snooze_for: 60 end)

      assert {:cancel, :nope} ==
               AshOban.job_control(fn -> raise AshOban.Errors.CancelJob, reason: :nope end)
    end

    test "returned job control errors are translated" do
      assert {:snooze, 30} ==
               AshOban.job_control(fn ->
                 {:error, AshOban.Errors.SnoozeJob.exception(snooze_for: 30)}
               end)

      assert {:cancel, :nope} ==
               AshOban.job_control(fn ->
                 {:error, AshOban.Errors.CancelJob.exception(reason: :nope)}
               end)
    end

    test "job control errors nested in an error class are translated" do
      error = Ash.Error.to_error_class(AshOban.Errors.SnoozeJob.exception(snooze_for: 10))

      assert {:snooze, 10} == AshOban.job_control(fn -> {:error, error} end)
      assert {:snooze, 10} == AshOban.job_control(fn -> raise error end)
    end
  end
end
