defmodule Nostrum.Voice.Event do
  @moduledoc false

  alias Nostrum.Cache.Me
  alias Nostrum.Cache.UserCache
  alias Nostrum.Constants
  alias Nostrum.Struct.VoiceWSState
  alias Nostrum.Voice
  alias Nostrum.Voice.Audio
  alias Nostrum.Voice.Crypto
  alias Nostrum.Voice.Payload
  alias Nostrum.Voice.Session

  require Logger

  @type frame :: {:text | :binary, iodata()}

  @spec handle(map(), VoiceWSState.t()) ::
          VoiceWSState.t() | {VoiceWSState.t(), frame() | [frame()]}
  def handle(payload, state) do
    state = update_sequence(state, payload)

    payload["op"]
    |> Constants.atom_from_voice_opcode()
    |> handle_event(payload, state)
  end

  defp update_sequence(state, %{"seq" => seq} = _payload), do: %{state | seq: seq}

  defp update_sequence(state, _payload), do: state

  defp handle_event(:ready, payload, state) do
    Logger.debug("VOICE READY")

    mode = Crypto.encryption_mode(state.bot_options, payload["d"]["modes"])

    voice =
      Voice.update_voice(state.voice_pid, state.guild_id,
        ssrc: payload["d"]["ssrc"],
        ip: payload["d"]["ip"],
        port: payload["d"]["port"],
        encryption_mode: mode,
        udp_socket: Audio.open_udp()
      )

    {my_ip, my_port} = Audio.discover_ip(voice.udp_socket, voice.ip, voice.port, voice.ssrc)

    {%{state | encryption_mode: mode}, Payload.select_protocol_payload(my_ip, my_port, mode)}
  end

  defp handle_event(:session_description, payload, state) do
    Logger.debug("VOICE SESSION DESCRIPTION")

    secret_key = payload["d"]["secret_key"] |> :erlang.list_to_binary()
    dave_protocol_version = payload["d"]["dave_protocol_version"] || 0

    # The session is created even without E2EE so that the call may upgrade later
    dave_session = Dave.new_session(max(dave_protocol_version, 1), Me.get().id, state.channel_id)

    state = %{
      state
      | secret_key: secret_key,
        dave_session: dave_session,
        dave_protocol_version: dave_protocol_version
    }

    Voice.update_voice_async(state.voice_pid, state.guild_id,
      secret_key: secret_key,
      rtp_sequence: 0,
      rtp_timestamp: 0,
      dave_session: active_dave_session(state)
    )

    Session.on_voice_ready(state.conn_pid)

    if dave_protocol_version > 0,
      do: {state, dave_key_package_payload(state)},
      else: state
  end

  defp handle_event(:heartbeat_ack, _payload, state) do
    Logger.debug("VOICE HEARTBEAT_ACK")
    %{state | last_heartbeat_ack: DateTime.utc_now(), heartbeat_ack: true}
  end

  defp handle_event(:resumed, _payload, state) do
    Logger.info("VOICE RESUMED")
    state
  end

  defp handle_event(:hello, payload, state) do
    state = %{state | heartbeat_interval: payload["d"]["heartbeat_interval"]}

    GenServer.cast(state.conn_pid, :heartbeat)

    if state.identified do
      Logger.info("RESUMING")
      {state, Payload.resume_payload(state)}
    else
      Logger.info("IDENTIFYING")
      {%{state | identified: true}, Payload.identify_payload(state)}
    end
  end

  defp handle_event(:client_connect, payload, state) do
    Logger.debug(fn ->
      user_id = payload["d"]["user_id"] |> String.to_integer()

      "Voice client connected: #{case UserCache.get(user_id) do
        {:ok, %{username: username}} -> username
        _ -> user_id
      end}"
    end)

    state
  end

  defp handle_event(:clients_connect, payload, state) do
    user_ids = Enum.map(payload["d"]["user_ids"], &String.to_integer/1)

    Logger.debug(fn -> "Voice clients connected: #{Enum.join(user_ids, ", ")}" end)

    connected_users = MapSet.union(state.dave_connected_users, MapSet.new(user_ids))
    %{state | dave_connected_users: connected_users}
  end

  defp handle_event(:client_disconnect, payload, state) do
    user_id = payload["d"]["user_id"] |> String.to_integer()

    Logger.debug(fn ->
      "Voice client disconnected: #{case UserCache.get(user_id) do
        {:ok, %{username: username}} -> username
        _ -> user_id
      end}"
    end)

    %{state | dave_connected_users: MapSet.delete(state.dave_connected_users, user_id)}
  end

  defp handle_event(:codec_info, _payload, state), do: state

  defp handle_event(:speaking, payload, state) do
    ssrc = payload["d"]["ssrc"]
    user_id = payload["d"]["user_id"] |> String.to_integer()
    ssrc_map = Map.put(state.ssrc_map, ssrc, user_id)
    %{state | ssrc_map: ssrc_map}
  end

  defp handle_event(:dave_prepare_transition, payload, state) do
    %{"transition_id" => transition_id, "protocol_version" => protocol_version} = payload["d"]
    Logger.debug("VOICE DAVE PREPARE TRANSITION #{transition_id} (v#{protocol_version})")

    pending = Map.put(state.dave_pending_transitions, transition_id, protocol_version)
    state = %{state | dave_pending_transitions: pending}

    # Transition id 0 is a (re)initialization that is executed immediately
    if transition_id == 0 do
      execute_dave_transition(state, transition_id)
    else
      # Accept frames that aren't end-to-end encrypted from senders that downgrade
      if protocol_version == 0, do: Dave.set_passthrough_mode(state.dave_session, true)
      {state, Payload.dave_transition_ready_payload(transition_id)}
    end
  end

  defp handle_event(:dave_execute_transition, payload, state) do
    execute_dave_transition(state, payload["d"]["transition_id"])
  end

  defp handle_event(:dave_prepare_epoch, payload, state) do
    %{"epoch" => epoch, "protocol_version" => protocol_version} = payload["d"]
    Logger.debug("VOICE DAVE PREPARE EPOCH #{epoch} (v#{protocol_version})")

    # Epoch 1 means a new MLS group is being created
    if epoch == 1 do
      {state, reply} = reinit_dave_session(%{state | dave_protocol_version: protocol_version})
      {sync_dave_session(state), reply}
    else
      state
    end
  end

  defp handle_event(:dave_mls_external_sender, payload, state) do
    Logger.debug("VOICE DAVE MLS EXTERNAL SENDER")
    :ok = Dave.set_external_sender(state.dave_session, payload["d"])
    state
  rescue
    error ->
      Logger.warning("Failed to set DAVE MLS external sender: #{Exception.message(error)}")
      state
  end

  defp handle_event(:dave_mls_proposals, payload, state) do
    Logger.debug("VOICE DAVE MLS PROPOSALS")

    <<operation_type::integer-8, proposals::binary>> = payload["d"]
    operation_type = if operation_type == 0, do: :append, else: :revoke
    user_ids = MapSet.to_list(state.dave_connected_users)

    case Dave.process_proposals(state.dave_session, operation_type, proposals, user_ids) do
      {nil, nil} ->
        state

      {commit, welcome} ->
        {state, Payload.dave_mls_commit_welcome_payload(commit, welcome)}

      :error ->
        Logger.warning("Failed to process DAVE MLS proposals")
        state
    end
  end

  defp handle_event(:dave_mls_announce_commit_transition, payload, state) do
    Logger.debug("VOICE DAVE MLS ANNOUNCE COMMIT TRANSITION")

    <<transition_id::integer-16, commit::binary>> = payload["d"]
    result = Dave.process_commit(state.dave_session, commit)
    prepare_dave_group_transition(state, transition_id, result)
  end

  defp handle_event(:dave_mls_welcome, payload, state) do
    Logger.debug("VOICE DAVE MLS WELCOME")

    <<transition_id::integer-16, welcome::binary>> = payload["d"]
    result = Dave.process_welcome(state.dave_session, welcome)
    prepare_dave_group_transition(state, transition_id, result)
  end

  defp handle_event(event, _payload, state) do
    Logger.debug("UNHANDLED VOICE GATEWAY EVENT #{event}")
    state
  end

  defp execute_dave_transition(state, transition_id) do
    case Map.pop(state.dave_pending_transitions, transition_id) do
      {nil, _pending} ->
        Logger.debug("No pending DAVE transition #{transition_id} to execute")
        state

      {protocol_version, pending} ->
        Logger.debug(
          "Executing DAVE transition #{transition_id} " <>
            "(v#{state.dave_protocol_version} -> v#{protocol_version})"
        )

        sync_dave_session(%{
          state
          | dave_protocol_version: protocol_version,
            dave_pending_transitions: pending
        })
    end
  end

  # Called after processing a commit or welcome that changes the members of the MLS group.
  # Transition id 0 is a (re)initialization of the group that isn't announced for execution.
  defp prepare_dave_group_transition(state, 0, :ok), do: state

  defp prepare_dave_group_transition(state, transition_id, :ok) do
    pending = Map.put(state.dave_pending_transitions, transition_id, state.dave_protocol_version)

    {%{state | dave_pending_transitions: pending},
     Payload.dave_transition_ready_payload(transition_id)}
  end

  # An unprocessable commit or welcome is reported so that the gateway re-adds us to the group
  defp prepare_dave_group_transition(state, transition_id, :error) do
    Logger.warning("Invalid DAVE MLS commit or welcome for transition #{transition_id}")

    {state, reply} = reinit_dave_session(state)
    {state, [Payload.dave_mls_invalid_commit_welcome_payload(transition_id) | reply]}
  end

  defp reinit_dave_session(%VoiceWSState{dave_protocol_version: 0} = state), do: {state, []}

  defp reinit_dave_session(%VoiceWSState{} = state) do
    :ok =
      Dave.reinit(state.dave_session, state.dave_protocol_version, Me.get().id, state.channel_id)

    {state, [dave_key_package_payload(state)]}
  end

  defp dave_key_package_payload(%VoiceWSState{dave_session: session}) do
    session
    |> Dave.get_serialized_key_package()
    |> Payload.dave_mls_key_package_payload()
  end

  # The voice state only holds the DAVE session while audio should be end-to-end encrypted
  defp active_dave_session(%VoiceWSState{dave_protocol_version: 0}), do: nil
  defp active_dave_session(%VoiceWSState{dave_session: session}), do: session

  defp sync_dave_session(%VoiceWSState{} = state) do
    Voice.update_voice_async(state.voice_pid, state.guild_id,
      dave_session: active_dave_session(state)
    )

    state
  end
end
