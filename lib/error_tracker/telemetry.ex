defmodule ErrorTracker.Telemetry do
  @moduledoc """
  Telemetry events of ErrorTracker.

  ErrorTracker emits some events to allow third parties to receive information
  of errors and occurrences stored.

  ### Error events

  Those occur during the life cycle of an error:

  * `[:error_tracker, :error, :new]`: is emitted when a new error is stored and
  no previous occurrences were known.

  * `[:error_tracker, :error, :resolved]`: is emitted when a new error is marked
  as resolved on the UI.

  * `[:error_tracker, :error, :unresolved]`: is emitted when a new error is
  marked as unresolved on the UI or a new occurrence is registered, moving the
  error to the unresolved state.

  ### Occurrence events

  There is only one event emitted for occurrences:

  * `[:error_tracker, :occurrence, :new]`: is emitted when a new occurrence is
  stored.

  If the error of the occurrence has been muted (see `ErrorTracker.mute/1`) the
  event is still emitted, but its `:muted` metadata will be `true`. Listeners
  that send notifications should check it and skip muted occurrences.

  ### Measures and metadata

  Each event is emitted with some measures and metadata, which can be used to
  receive information without having to query the database again:

  | event                                   | measures       | metadata                |
  | --------------------------------------- | -------------- | ----------------------- |
  | `[:error_tracker, :error, :new]`        | `:system_time` | `:error`                |
  | `[:error_tracker, :error, :unresolved]` | `:system_time` | `:error`                |
  | `[:error_tracker, :error, :resolved]`   | `:system_time` | `:error`                |
  | `[:error_tracker, :occurrence, :new]`   | `:system_time` | `:occurrence`, `:muted` |
  """

  @doc false
  def new_error(error) do
    measurements = %{system_time: System.system_time()}
    metadata = %{error: error}
    :telemetry.execute([:error_tracker, :error, :new], measurements, metadata)
  end

  @doc false
  def unresolved_error(error) do
    measurements = %{system_time: System.system_time()}
    metadata = %{error: error}
    :telemetry.execute([:error_tracker, :error, :unresolved], measurements, metadata)
  end

  @doc false
  def resolved_error(error) do
    measurements = %{system_time: System.system_time()}
    metadata = %{error: error}
    :telemetry.execute([:error_tracker, :error, :resolved], measurements, metadata)
  end

  @doc false
  def new_occurrence(occurrence, muted) do
    measurements = %{system_time: System.system_time()}
    metadata = %{occurrence: occurrence, muted: muted}
    :telemetry.execute([:error_tracker, :occurrence, :new], measurements, metadata)
  end
end
