# SPDX-FileCopyrightText: 2023 ash_oban contributors <https://github.com/ash-project/ash_oban/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshOban.Errors.Snooze do
  @moduledoc """
  Returned or raised from an action to snooze the Oban job that is running it.

  See `AshOban.snooze/1` for more.
  """
  use Splode.Error, fields: [:seconds], class: :invalid

  def message(%{seconds: seconds}) do
    "Snoozing job for #{seconds} seconds"
  end
end
