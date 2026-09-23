defmodule Nostrum.Voice.Crypto.Dave do
  @moduledoc """
  Internal module that handles the Discord Audio & Video End-to-End Encryption (DAVE) protocol

  DAVE end-to-end encrypts opus frames with keys derived from an MLS group that is
  negotiated over the voice websocket. The end-to-end encrypted frames are then
  transport encrypted by `Nostrum.Voice.Crypto` as usual.

  MLS group management and frame encryption are delegated to the `:dave` package.
  See the [DAVE protocol whitepaper](https://daveprotocol.com/) for details.
  """

  alias Nostrum.Cache.Me
  alias Nostrum.Struct.VoiceWSState
  alias Nostrum.Voice.Payload

  require Logger

  @opus_silence <<0xF8, 0xFF, 0xFE>>

  @magic_marker <<0xFA, 0xFA>>

  @type frame :: {:text | :binary, iodata()}

  @doc false
  @spec reinit(VoiceWSState.t()) :: {VoiceWSState.t(), [frame()]}
  def reinit(%VoiceWSState{dave_protocol_version: version} = state)
      when is_integer(version) and version > 0 do
    user_id = Me.get().id

    session =
      case state.dave_session do
        nil ->
          session = Dave.new_session(version, user_id, state.channel_id)

          if state.dave_external_sender,
            do: Dave.set_external_sender(session, state.dave_external_sender)

          session

        session ->
          :ok = Dave.reinit(session, version, user_id, state.channel_id)
          session
      end

    key_package = Dave.get_serialized_key_package(session)

    {%{state | dave_session: session},
     [{:binary, Payload.dave_mls_key_package_payload(key_package)}]}
  end

  def reinit(%VoiceWSState{dave_session: nil} = state), do: {state, []}

  def reinit(%VoiceWSState{dave_session: session} = state) do
    Dave.reset(session)
    Dave.set_passthrough_mode(session, true)
    {state, []}
  end

  @doc false
  @spec set_external_sender(VoiceWSState.t(), binary()) :: VoiceWSState.t()
  def set_external_sender(%VoiceWSState{dave_session: session} = state, external_sender) do
    if session, do: Dave.set_external_sender(session, external_sender)

    %{state | dave_external_sender: external_sender}
  rescue
    error ->
      Logger.warning("Failed to set DAVE external sender: #{inspect(error)}")
      %{state | dave_external_sender: external_sender}
  end

  @doc false
  @spec prepare_transition(VoiceWSState.t(), non_neg_integer(), non_neg_integer()) ::
          {VoiceWSState.t(), [frame()]}
  def prepare_transition(state, transition_id, protocol_version) do
    state = %{
      state
      | dave_pending_transition: %{
          transition_id: transition_id,
          protocol_version: protocol_version
        }
    }

    # A transition id of 0 is for (re)initialization and is executed immediately
    if transition_id == 0 do
      {execute_transition(state, transition_id), []}
    else
      if protocol_version == 0 and state.dave_session,
        do: Dave.set_passthrough_mode(state.dave_session, true)

      {state, [{:text, Payload.dave_transition_ready_payload(transition_id)}]}
    end
  end

  @doc false
  @spec execute_transition(VoiceWSState.t(), non_neg_integer()) :: VoiceWSState.t()
  def execute_transition(
        %VoiceWSState{
          dave_pending_transition: %{transition_id: transition_id, protocol_version: version}
        } = state,
        transition_id
      ) do
    Logger.debug(
      "DAVE transition #{transition_id} executed (v#{state.dave_protocol_version} -> v#{version})"
    )

    # Allow unencrypted frames from other users for a short period after upgrading
    if state.dave_protocol_version == 0 and version > 0 and state.dave_session,
      do: Dave.set_passthrough_mode(state.dave_session, true)

    %{state | dave_protocol_version: version, dave_pending_transition: nil}
  end

  def execute_transition(state, transition_id) do
    Logger.debug("Received DAVE execute transition #{transition_id} with no matching transition")
    %{state | dave_pending_transition: nil}
  end

  @doc false
  @spec prepare_epoch(VoiceWSState.t(), non_neg_integer(), non_neg_integer()) ::
          {VoiceWSState.t(), [frame()]}
  def prepare_epoch(state, 1 = _epoch, protocol_version) do
    reinit(%{state | dave_protocol_version: protocol_version})
  end

  def prepare_epoch(state, _epoch, _protocol_version), do: {state, []}

  @doc false
  @spec process_proposals(VoiceWSState.t(), binary()) :: {VoiceWSState.t(), [frame()]}
  def process_proposals(%VoiceWSState{dave_session: nil} = state, _payload), do: {state, []}

  def process_proposals(state, <<operation_type, proposals::binary>>) do
    operation_type = if operation_type == 0, do: :append, else: :revoke
    user_ids = MapSet.to_list(state.connected_users)

    case Dave.process_proposals(state.dave_session, operation_type, proposals, user_ids) do
      {commit, welcome} when is_binary(commit) ->
        {state, [{:binary, Payload.dave_mls_commit_welcome_payload(commit, welcome)}]}

      {nil, _welcome} ->
        {state, []}

      :error ->
        Logger.warning("Failed to process DAVE MLS proposals")
        {state, []}
    end
  end

  @doc false
  @spec process_commit(VoiceWSState.t(), binary()) :: {VoiceWSState.t(), [frame()]}
  def process_commit(%VoiceWSState{dave_session: nil} = state, _payload), do: {state, []}

  def process_commit(state, <<transition_id::16, commit::binary>>) do
    state.dave_session
    |> Dave.process_commit(commit)
    |> on_group_transition(state, transition_id)
  end

  @doc false
  @spec process_welcome(VoiceWSState.t(), binary()) :: {VoiceWSState.t(), [frame()]}
  def process_welcome(%VoiceWSState{dave_session: nil} = state, _payload), do: {state, []}

  def process_welcome(state, <<transition_id::16, welcome::binary>>) do
    state.dave_session
    |> Dave.process_welcome(welcome)
    |> on_group_transition(state, transition_id)
  end

  defp on_group_transition(:ok, state, 0 = _transition_id), do: {state, []}

  defp on_group_transition(:ok, state, transition_id) do
    state = %{
      state
      | dave_pending_transition: %{
          transition_id: transition_id,
          protocol_version: state.dave_protocol_version
        }
    }

    {state, [{:text, Payload.dave_transition_ready_payload(transition_id)}]}
  end

  # An unprocessable commit or welcome requires asking the voice gateway to remove
  # and re-add us to the group, and sending a fresh key package to be re-added with
  defp on_group_transition(:error, state, transition_id) do
    Logger.warning("Invalid DAVE MLS commit or welcome for transition #{transition_id}")

    {state, key_package} = reinit(state)

    {state,
     [{:text, Payload.dave_mls_invalid_commit_welcome_payload(transition_id)} | key_package]}
  end

  @doc false
  @spec encrypt(map(), binary()) :: binary()
  def encrypt(%{dave_session: session, dave_protocol_version: version}, frame)
      when is_reference(session) and is_integer(version) and version > 0 and
             frame != @opus_silence do
    case Dave.encrypt(session, :audio, :opus, frame) do
      :error -> frame
      encrypted -> encrypted
    end
  end

  def encrypt(_voice, frame), do: frame

  @doc false
  @spec decrypt(Dave.session() | nil, Nostrum.Struct.User.id() | nil, binary()) ::
          {:ok, binary()} | :error
  def decrypt(session, user_id, frame) do
    cond do
      not dave_frame?(frame) ->
        {:ok, frame}

      is_reference(session) and is_integer(user_id) ->
        case Dave.decrypt(session, user_id, :audio, frame) do
          :error -> :error
          decrypted -> {:ok, decrypted}
        end

      true ->
        :error
    end
  end

  defp dave_frame?(frame) when byte_size(frame) > byte_size(@magic_marker),
    do: binary_part(frame, byte_size(frame), -byte_size(@magic_marker)) == @magic_marker

  defp dave_frame?(_frame), do: false
end
