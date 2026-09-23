defmodule Nostrum.Voice.E2EE do
  @moduledoc false

  # Discord Audio & Video End-to-End Encryption (DAVE) protocol
  # https://daveprotocol.com

  alias Nostrum.Cache.Me
  alias Nostrum.Struct.Channel
  alias Nostrum.Struct.VoiceState
  alias Nostrum.Struct.VoiceWSState
  alias Nostrum.Voice
  alias Nostrum.Voice.Payload

  require Logger

  @opus_silence <<0xF8, 0xFF, 0xFE>>

  @type frames :: [:gun.ws_frame()]

  @spec new_session(Channel.id()) :: Dave.session()
  def new_session(channel_id) do
    Dave.new_session(Dave.max_protocol_version(), Me.get().id, channel_id)
  end

  @spec init(VoiceWSState.t(), non_neg_integer()) :: {VoiceWSState.t(), frames()}
  def init(%VoiceWSState{} = state, protocol_version) do
    Logger.debug("DAVE protocol version #{protocol_version}")

    {state, frames} = reinit(%{state | dave_protocol_version: protocol_version})

    {sync_voice(state), frames}
  end

  @spec prepare_transition(VoiceWSState.t(), map()) :: {VoiceWSState.t(), frames()}
  def prepare_transition(%VoiceWSState{} = state, %{
        "transition_id" => transition_id,
        "protocol_version" => protocol_version
      }) do
    Logger.debug("Preparing DAVE transition #{transition_id} (v#{protocol_version})")

    state = put_pending_transition(state, transition_id, protocol_version)

    # Transition id 0 is for (re)initialization and is executed immediately
    if transition_id == 0 do
      {execute_transition(state, transition_id), []}
    else
      if protocol_version == 0, do: :ok = Dave.set_passthrough_mode(state.dave_session, true)
      {state, [transition_ready_frame(transition_id)]}
    end
  end

  @spec execute_transition(VoiceWSState.t(), non_neg_integer()) :: VoiceWSState.t()
  def execute_transition(%VoiceWSState{} = state, transition_id) do
    case Map.pop(state.dave_pending_transitions, transition_id) do
      {nil, _pending} ->
        Logger.debug("No pending DAVE transition #{transition_id} to execute")
        state

      {protocol_version, pending} ->
        # Frames that aren't end-to-end encrypted are still accepted for a short grace period
        if protocol_version > 0, do: :ok = Dave.set_passthrough_mode(state.dave_session, false)

        Logger.debug(
          "Executed DAVE transition #{transition_id} " <>
            "(v#{state.dave_protocol_version} -> v#{protocol_version})"
        )

        sync_voice(%{
          state
          | dave_protocol_version: protocol_version,
            dave_pending_transitions: pending
        })
    end
  end

  @spec prepare_epoch(VoiceWSState.t(), map()) :: {VoiceWSState.t(), frames()}
  def prepare_epoch(%VoiceWSState{} = state, %{"epoch" => 1, "protocol_version" => version})
      when version > 0 do
    Logger.debug("Preparing new DAVE MLS group (v#{version})")

    {state, frames} = reinit(%{state | dave_protocol_version: version})

    {sync_voice(state), frames}
  end

  def prepare_epoch(%VoiceWSState{} = state, _payload), do: {state, []}

  @spec set_external_sender(VoiceWSState.t(), binary()) :: {VoiceWSState.t(), frames()}
  def set_external_sender(%VoiceWSState{} = state, external_sender) do
    :ok = Dave.set_external_sender(state.dave_session, external_sender)
    {state, []}
  rescue
    error ->
      Logger.warning("Failed to set DAVE MLS external sender: #{Exception.message(error)}")
      {state, []}
  end

  @spec process_proposals(VoiceWSState.t(), binary()) :: {VoiceWSState.t(), frames()}
  def process_proposals(%VoiceWSState{} = state, <<operation_type, proposals::binary>>) do
    user_ids = MapSet.to_list(state.connected_user_ids)

    case Dave.process_proposals(
           state.dave_session,
           proposals_operation(operation_type),
           proposals,
           user_ids
         ) do
      {nil, _welcome} ->
        {state, []}

      {commit, welcome} ->
        {state, [{:binary, Payload.dave_mls_commit_welcome_payload(commit, welcome)}]}

      :error ->
        Logger.warning("Failed to process DAVE MLS proposals")
        {state, []}
    end
  end

  @spec process_commit(VoiceWSState.t(), binary()) :: {VoiceWSState.t(), frames()}
  def process_commit(%VoiceWSState{} = state, <<transition_id::16, commit::binary>>) do
    state.dave_session
    |> Dave.process_commit(commit)
    |> on_transition_processed(state, transition_id)
  end

  @spec process_welcome(VoiceWSState.t(), binary()) :: {VoiceWSState.t(), frames()}
  def process_welcome(%VoiceWSState{} = state, <<transition_id::16, welcome::binary>>) do
    state.dave_session
    |> Dave.process_welcome(welcome)
    |> on_transition_processed(state, transition_id)
  end

  @doc """
  End-to-end encrypts an outgoing opus frame if the DAVE protocol is in effect.
  """
  @spec encrypt(VoiceState.t(), binary()) :: binary()
  def encrypt(%VoiceState{dave_protocol_version: version}, frame) when version in [nil, 0],
    do: frame

  def encrypt(%VoiceState{dave_session: session}, frame) do
    # Until the MLS group has been established there are no keys to encrypt with
    case Dave.encrypt(session, :audio, :opus, frame) do
      :error -> frame
      encrypted -> encrypted
    end
  end

  @doc """
  Decrypts an incoming opus frame if the DAVE protocol is in effect.

  The sender of the frame is identified by the RTP SSRC, so `:error` is returned
  if the SSRC is not yet known or the frame otherwise cannot be decrypted.
  """
  @spec decrypt(VoiceWSState.t(), Voice.rtp_ssrc(), binary()) :: binary() | :error
  def decrypt(%VoiceWSState{dave_protocol_version: version}, _ssrc, opus)
      when version in [nil, 0] or opus == @opus_silence,
      do: opus

  def decrypt(%VoiceWSState{dave_session: session, ssrc_map: ssrc_map}, ssrc, opus) do
    case ssrc_map do
      %{^ssrc => user_id} -> Dave.decrypt(session, user_id, :audio, opus)
      _unknown_ssrc -> :error
    end
  end

  defp on_transition_processed(:ok, state, 0), do: {state, []}

  defp on_transition_processed(:ok, state, transition_id) do
    state = put_pending_transition(state, transition_id, state.dave_protocol_version)
    {state, [transition_ready_frame(transition_id)]}
  end

  defp on_transition_processed(:error, state, transition_id) do
    Logger.warning(
      "Failed to process DAVE MLS commit or welcome for transition #{transition_id}, " <>
        "requesting to be re-added to the group"
    )

    {state, frames} = reinit(state)

    {state, [invalid_commit_welcome_frame(transition_id) | frames]}
  end

  defp reinit(%VoiceWSState{dave_protocol_version: 0} = state) do
    _result = Dave.reset(state.dave_session)
    :ok = Dave.set_passthrough_mode(state.dave_session, true)
    {state, []}
  end

  defp reinit(%VoiceWSState{dave_session: session} = state) do
    :ok = Dave.reinit(session, state.dave_protocol_version, Me.get().id, state.channel_id)
    {state, [key_package_frame(session)]}
  end

  defp sync_voice(%VoiceWSState{} = state) do
    Voice.update_voice_async(state.voice_pid, state.guild_id,
      dave_session: state.dave_session,
      dave_protocol_version: state.dave_protocol_version
    )

    state
  end

  defp put_pending_transition(state, transition_id, protocol_version) do
    pending = Map.put(state.dave_pending_transitions, transition_id, protocol_version)
    %{state | dave_pending_transitions: pending}
  end

  defp proposals_operation(0), do: :append
  defp proposals_operation(1), do: :revoke

  defp transition_ready_frame(transition_id),
    do: {:text, Payload.dave_transition_ready_payload(transition_id)}

  defp invalid_commit_welcome_frame(transition_id),
    do: {:text, Payload.dave_mls_invalid_commit_welcome_payload(transition_id)}

  defp key_package_frame(session) do
    key_package = Dave.get_serialized_key_package(session)
    {:binary, Payload.dave_mls_key_package_payload(key_package)}
  end
end
