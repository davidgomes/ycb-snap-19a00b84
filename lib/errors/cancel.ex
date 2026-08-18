# SPDX-FileCopyrightText: 2023 ash_oban contributors <https://github.com/ash-project/ash_oban/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshOban.Errors.Cancel do
  @moduledoc """
  Returned or raised from an action to cancel the Oban job that is running it.

  See `AshOban.cancel/1` for more.
  """
  use Splode.Error, fields: [:reason], class: :invalid

  def message(%{reason: reason}) when is_binary(reason) do
    "Cancelling job: #{reason}"
  end

  def message(%{reason: reason}) do
    "Cancelling job: #{inspect(reason)}"
  end
end
