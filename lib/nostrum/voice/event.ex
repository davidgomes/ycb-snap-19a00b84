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

  @type ws_frame :: {:text | :binary, iodata()}

  @spec handle(map() | binary(), VoiceWSState.t()) ::
          VoiceWSState.t() | {VoiceWSState.t(), ws_frame() | [ws_frame()]}
  def handle(payload, state) when is_map(payload) do
    state = update_sequence(state, payload)

    payload["op"]
    |> Constants.atom_from_voice_opcode()
    |> handle_event(payload, state)
  end

  # Server-sent binary messages are a 16-bit sequence number and an opcode byte
  # followed by the payload
  def handle(<<seq::16, opcode::8, data::binary>>, state) do
    opcode
    |> Constants.atom_from_voice_opcode()
    |> handle_binary_event(data, %{state | seq: seq})
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

    Voice.update_voice_async(state.voice_pid, state.guild_id,
      secret_key: secret_key,
      rtp_sequence: 0,
      rtp_timestamp: 0
    )

    Session.on_voice_ready(state.conn_pid)

    dave_reinit(%{state | secret_key: secret_key, dave_protocol_version: dave_protocol_version})
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

  defp handle_event(:clients_connect, payload, state) do
    user_ids = Enum.map(payload["d"]["user_ids"], &String.to_integer/1)

    Enum.each(user_ids, fn user_id ->
      Logger.debug(fn -> "Voice client connected: #{username(user_id)}" end)
    end)

    %{state | connected_users: MapSet.union(state.connected_users, MapSet.new(user_ids))}
  end

  defp handle_event(:client_connect, payload, state) do
    user_id = payload["d"]["user_id"] |> String.to_integer()

    Logger.debug(fn -> "Voice client connected: #{username(user_id)}" end)

    %{state | connected_users: MapSet.put(state.connected_users, user_id)}
  end

  defp handle_event(:client_disconnect, payload, state) do
    user_id = payload["d"]["user_id"] |> String.to_integer()

    Logger.debug(fn -> "Voice client disconnected: #{username(user_id)}" end)

    %{state | connected_users: MapSet.delete(state.connected_users, user_id)}
  end

  defp handle_event(:codec_info, _payload, state), do: state

  defp handle_event(:speaking, payload, state) do
    ssrc = payload["d"]["ssrc"]
    user_id = payload["d"]["user_id"] |> String.to_integer()
    ssrc_map = Map.put(state.ssrc_map, ssrc, user_id)
    %{state | ssrc_map: ssrc_map}
  end

  defp handle_event(:dave_prepare_transition, payload, state) do
    %{"transition_id" => transition_id, "protocol_version" => version} = payload["d"]

    state = put_pending_transition(state, transition_id, version)

    if transition_id == 0 do
      execute_transition(state, transition_id)
    else
      if version == 0 and is_reference(state.dave_session),
        do: Dave.set_passthrough_mode(state.dave_session, true)

      {state, Payload.dave_transition_ready_payload(transition_id)}
    end
  end

  defp handle_event(:dave_execute_transition, payload, state) do
    execute_transition(state, payload["d"]["transition_id"])
  end

  # An epoch of 1 signals the creation of a new MLS group
  defp handle_event(:dave_prepare_epoch, payload, state) do
    case payload["d"] do
      %{"epoch" => 1, "protocol_version" => version} ->
        dave_reinit(%{state | dave_protocol_version: version})

      _ ->
        state
    end
  end

  defp handle_event(event, _payload, state) do
    Logger.debug("UNHANDLED VOICE GATEWAY EVENT #{event}")
    state
  end

  defp handle_binary_event(event, data, %{dave_session: session} = state)
       when is_reference(session) do
    handle_dave_event(event, data, session, state)
  end

  defp handle_binary_event(event, _data, state) do
    Logger.debug("UNHANDLED VOICE GATEWAY BINARY EVENT #{event}")
    state
  end

  defp handle_dave_event(:dave_mls_external_sender, external_sender, session, state) do
    Dave.set_external_sender(session, external_sender)
    state
  end

  defp handle_dave_event(:dave_mls_proposals, <<op_type, proposals::binary>>, session, state) do
    operation_type = if op_type == 0, do: :append, else: :revoke
    user_ids = [Me.get().id | MapSet.to_list(state.connected_users)]

    case Dave.process_proposals(session, operation_type, proposals, user_ids) do
      {commit, welcome} when is_binary(commit) ->
        {state, Payload.dave_commit_welcome_payload(commit, welcome)}

      _ ->
        state
    end
  end

  defp handle_dave_event(
         :dave_mls_announce_commit_transition,
         <<transition_id::16, commit::binary>>,
         session,
         state
       ) do
    session
    |> Dave.process_commit(commit)
    |> on_commit_or_welcome(transition_id, state)
  end

  defp handle_dave_event(
         :dave_mls_welcome,
         <<transition_id::16, welcome::binary>>,
         session,
         state
       ) do
    session
    |> Dave.process_welcome(welcome)
    |> on_commit_or_welcome(transition_id, state)
  end

  defp handle_dave_event(event, _data, _session, state) do
    Logger.debug("UNHANDLED VOICE GATEWAY BINARY EVENT #{event}")
    state
  end

  defp on_commit_or_welcome(:ok, 0 = _transition_id, state), do: state

  defp on_commit_or_welcome(:ok, transition_id, state) do
    state = put_pending_transition(state, transition_id, state.dave_protocol_version)
    {state, Payload.dave_transition_ready_payload(transition_id)}
  end

  defp on_commit_or_welcome(_error, transition_id, state) do
    Logger.warning(
      "Invalid DAVE commit or welcome for transition #{transition_id}, reinitializing"
    )

    {state, frames} = dave_reinit(state)
    {state, [Payload.dave_invalid_commit_welcome_payload(transition_id) | frames]}
  end

  defp put_pending_transition(state, transition_id, version) do
    %{
      state
      | dave_pending_transitions: Map.put(state.dave_pending_transitions, transition_id, version)
    }
  end

  defp execute_transition(state, transition_id) do
    case Map.pop(state.dave_pending_transitions, transition_id) do
      {nil, _pending} ->
        Logger.warning("Received execute for unknown DAVE transition #{transition_id}")
        state

      {version, pending} ->
        state = %{state | dave_pending_transitions: pending}
        apply_transition(state, version)
    end
  end

  defp apply_transition(%{dave_protocol_version: old_version} = state, 0 = _version)
       when old_version > 0 do
    {state, _frames = []} =
      dave_reinit(%{state | dave_protocol_version: 0, dave_downgraded: true})

    state
  end

  defp apply_transition(%{dave_downgraded: true, dave_session: session} = state, version)
       when version > 0 and is_reference(session) do
    Dave.set_passthrough_mode(session, false)
    %{state | dave_protocol_version: version, dave_downgraded: false}
  end

  defp apply_transition(state, version), do: %{state | dave_protocol_version: version}

  # (Re)initializes the DAVE session for the negotiated protocol version, returning
  # the key package to be sent to join the MLS group. A protocol version of 0 means
  # media is not end-to-end encrypted.
  defp dave_reinit(%{dave_protocol_version: version} = state) when version > 0 do
    user_id = Me.get().id

    session =
      case state.dave_session do
        nil ->
          session = Dave.new_session(version, user_id, state.channel_id)
          Voice.update_voice_async(state.voice_pid, state.guild_id, dave_session: session)
          session

        session ->
          Dave.reinit(session, version, user_id, state.channel_id)
          session
      end

    key_package = Dave.get_serialized_key_package(session)

    {%{state | dave_session: session}, [Payload.dave_key_package_payload(key_package)]}
  end

  defp dave_reinit(%{dave_session: session} = state) when is_reference(session) do
    Dave.reset(session)
    Dave.set_passthrough_mode(session, true)
    {state, []}
  end

  defp dave_reinit(state), do: {state, []}

  defp username(user_id) do
    case UserCache.get(user_id) do
      {:ok, %{username: username}} -> username
      _ -> user_id
    end
  end
end
