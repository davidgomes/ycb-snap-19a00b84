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

  * `[:error_tracker, :error, :muted]`: is emitted when an error is muted on
  the UI.

  * `[:error_tracker, :error, :unmuted]`: is emitted when an error is unmuted
  on the UI.

  ### Occurrence events

  There is only one event emitted for occurrences:

  * `[:error_tracker, :occurrence, :new]`: is emitted when a new occurrence is
  stored.

  ### Muted errors

  Errors can be muted from the UI. Occurrences of muted errors keep being
  tracked and stored, but no `:new`, `:unresolved` or `:occurrence` event is
  emitted for them.

  ### Measures and metadata

  Each event is emitted with some measures and metadata, which can be used to
  receive information without having to query the database again:

  | event                                   | measures       | metadata      |
  | --------------------------------------- | -------------- | ------------- |
  | `[:error_tracker, :error, :new]`        | `:system_time` | `:error`      |
  | `[:error_tracker, :error, :unresolved]` | `:system_time` | `:error`      |
  | `[:error_tracker, :error, :resolved]`   | `:system_time` | `:error`      |
  | `[:error_tracker, :error, :muted]`      | `:system_time` | `:error`      |
  | `[:error_tracker, :error, :unmuted]`    | `:system_time` | `:error`      |
  | `[:error_tracker, :occurrence, :new]`   | `:system_time` | `:occurrence` |
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
  def muted_error(error) do
    measurements = %{system_time: System.system_time()}
    metadata = %{error: error}
    :telemetry.execute([:error_tracker, :error, :muted], measurements, metadata)
  end

  @doc false
  def unmuted_error(error) do
    measurements = %{system_time: System.system_time()}
    metadata = %{error: error}
    :telemetry.execute([:error_tracker, :error, :unmuted], measurements, metadata)
  end

  @doc false
  def new_occurrence(occurrence) do
    measurements = %{system_time: System.system_time()}
    metadata = %{occurrence: occurrence}
    :telemetry.execute([:error_tracker, :occurrence, :new], measurements, metadata)
  end
end
