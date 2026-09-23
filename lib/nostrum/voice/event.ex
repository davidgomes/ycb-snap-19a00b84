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

  @spec handle(map(), VoiceWSState.t()) ::
          VoiceWSState.t() | {VoiceWSState.t(), :gun.ws_frame() | [:gun.ws_frame()]}
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

    {state, frames} =
      reinit_dave_session(%{
        state
        | secret_key: secret_key,
          dave_protocol_version: dave_protocol_version
      })

    Voice.update_voice_async(state.voice_pid, state.guild_id,
      secret_key: secret_key,
      rtp_sequence: 0,
      rtp_timestamp: 0,
      dave_session: Crypto.active_dave_session(state)
    )

    Session.on_voice_ready(state.conn_pid)

    {state, frames}
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

    Logger.debug(fn ->
      "Voice clients connected: #{Enum.map_join(user_ids, ", ", &username/1)}"
    end)

    %{state | connected_users: MapSet.union(state.connected_users, MapSet.new(user_ids))}
  end

  defp handle_event(:client_connect, payload, state) do
    Logger.debug(fn ->
      user_id = payload["d"]["user_id"] |> String.to_integer()

      "Voice client connected: #{username(user_id)}"
    end)

    state
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
    %{"transition_id" => transition_id, "protocol_version" => protocol_version} = payload["d"]

    Logger.debug("VOICE DAVE PREPARE TRANSITION #{transition_id} (v#{protocol_version})")

    # Receivers must accept unencrypted frames once senders begin downgrading
    if protocol_version == 0 and state.dave_session,
      do: :ok = Dave.set_passthrough_mode(state.dave_session, true)

    prepare_transition(state, transition_id, protocol_version)
  end

  defp handle_event(:dave_execute_transition, payload, state) do
    transition_id = payload["d"]["transition_id"]

    Logger.debug("VOICE DAVE EXECUTE TRANSITION #{transition_id}")

    execute_transition(state, transition_id)
  end

  defp handle_event(:dave_prepare_epoch, payload, state) do
    %{"epoch" => epoch, "protocol_version" => protocol_version} = payload["d"]

    Logger.debug("VOICE DAVE PREPARE EPOCH #{epoch} (v#{protocol_version})")

    # Epoch 1 means a new MLS group is being created for the given protocol version
    if epoch == 1 do
      {state, frames} = reinit_dave_session(%{state | dave_protocol_version: protocol_version})
      sync_dave_session(state)
      {state, frames}
    else
      state
    end
  end

  defp handle_event(:mls_external_sender, payload, state) do
    Logger.debug("VOICE MLS EXTERNAL SENDER")

    state = ensure_dave_session(state)

    try do
      :ok = Dave.set_external_sender(state.dave_session, payload["d"])
    rescue
      error in ErlangError ->
        Logger.warning("Unable to set MLS external sender: #{inspect(error.original)}")
    end

    state
  end

  defp handle_event(event, _payload, %{dave_session: nil} = state)
       when event in [:mls_proposals, :mls_announce_commit_transition, :mls_welcome] do
    Logger.warning("Received #{event} without a DAVE session")
    state
  end

  defp handle_event(:mls_proposals, %{"d" => <<operation_type, proposals::binary>>}, state) do
    Logger.debug("VOICE MLS PROPOSALS")

    operation_type = if(operation_type == 0, do: :append, else: :revoke)
    user_ids = MapSet.to_list(state.connected_users)

    case Dave.process_proposals(state.dave_session, operation_type, proposals, user_ids) do
      {nil, _welcome} ->
        state

      {commit, welcome} ->
        {state, Payload.mls_commit_welcome_payload(commit, welcome)}

      :error ->
        Logger.warning("Unable to process MLS proposals")
        state
    end
  end

  defp handle_event(
         :mls_announce_commit_transition,
         %{"d" => <<transition_id::16, commit::binary>>},
         state
       ) do
    Logger.debug("VOICE MLS ANNOUNCE COMMIT TRANSITION #{transition_id}")

    state.dave_session
    |> Dave.process_commit(commit)
    |> prepare_mls_transition(transition_id, state)
  end

  defp handle_event(:mls_welcome, %{"d" => <<transition_id::16, welcome::binary>>}, state) do
    Logger.debug("VOICE MLS WELCOME #{transition_id}")

    state.dave_session
    |> Dave.process_welcome(welcome)
    |> prepare_mls_transition(transition_id, state)
  end

  defp handle_event(event, _payload, state) do
    Logger.debug("UNHANDLED VOICE GATEWAY EVENT #{event}")
    state
  end

  defp username(user_id) do
    case UserCache.get(user_id) do
      {:ok, %{username: username}} -> username
      _ -> user_id
    end
  end

  defp prepare_mls_transition(:ok, transition_id, state),
    do: prepare_transition(state, transition_id, state.dave_protocol_version)

  # An unprocessable commit or welcome is reported to the voice gateway along with a
  # new key package so that we get removed and re-added to the MLS group
  defp prepare_mls_transition(:error, transition_id, state) do
    Logger.warning("Unable to process MLS commit or welcome for transition #{transition_id}")

    {state, frames} = reinit_dave_session(state)

    {state, [Payload.mls_invalid_commit_welcome_payload(transition_id) | frames]}
  end

  # Transition id 0 (re)initializes the session and is executed immediately
  defp prepare_transition(state, 0 = transition_id, protocol_version) do
    state
    |> put_pending_transition(transition_id, protocol_version)
    |> execute_transition(transition_id)
  end

  defp prepare_transition(state, transition_id, protocol_version) do
    state = put_pending_transition(state, transition_id, protocol_version)

    {state, Payload.dave_transition_ready_payload(transition_id)}
  end

  defp put_pending_transition(state, transition_id, protocol_version) do
    pending = Map.put(state.dave_pending_transitions, transition_id, protocol_version)
    %{state | dave_pending_transitions: pending}
  end

  defp execute_transition(state, transition_id) do
    case Map.pop(state.dave_pending_transitions, transition_id) do
      {nil, _pending} ->
        Logger.debug("No pending DAVE transition #{transition_id} to execute")
        state

      {protocol_version, pending} ->
        put_dave_protocol_version(%{state | dave_pending_transitions: pending}, protocol_version)
    end
  end

  defp put_dave_protocol_version(%{dave_protocol_version: version} = state, version) do
    maybe_end_passthrough(state)
  end

  defp put_dave_protocol_version(state, 0) do
    Logger.debug("DAVE protocol downgraded")

    state = %{state | dave_protocol_version: 0, dave_downgraded: true}
    sync_dave_session(state)
    state
  end

  defp put_dave_protocol_version(state, protocol_version) do
    state = maybe_end_passthrough(%{state | dave_protocol_version: protocol_version})
    sync_dave_session(state)
    state
  end

  # After upgrading from a downgrade, unencrypted frames are only allowed for a short grace period
  defp maybe_end_passthrough(%{dave_downgraded: true, dave_protocol_version: version} = state)
       when version > 0 do
    Logger.debug("DAVE protocol upgraded")

    :ok = Dave.set_passthrough_mode(state.dave_session, false)
    %{state | dave_downgraded: false}
  end

  defp maybe_end_passthrough(state), do: state

  # Keeps the session used for encrypting outgoing audio in sync with the protocol version
  defp sync_dave_session(state) do
    Voice.update_voice_async(state.voice_pid, state.guild_id,
      dave_session: Crypto.active_dave_session(state)
    )
  end

  # The external sender may arrive before the call has upgraded to DAVE, in which case
  # the session is created ahead of time so the sender is retained when it's reinitialized
  defp ensure_dave_session(%{dave_session: nil} = state) do
    session = Dave.new_session(Dave.max_protocol_version(), Me.get().id, state.channel_id)
    %{state | dave_session: session}
  end

  defp ensure_dave_session(state), do: state

  defp reinit_dave_session(%{dave_protocol_version: 0, dave_session: nil} = state),
    do: {state, []}

  defp reinit_dave_session(%{dave_protocol_version: 0, dave_session: session} = state) do
    _result = Dave.reset(session)
    :ok = Dave.set_passthrough_mode(session, true)
    {state, []}
  end

  defp reinit_dave_session(%{dave_protocol_version: version, dave_session: session} = state) do
    user_id = Me.get().id

    session =
      if session do
        :ok = Dave.reinit(session, version, user_id, state.channel_id)
        session
      else
        Dave.new_session(version, user_id, state.channel_id)
      end

    key_package = Dave.get_serialized_key_package(session)

    {%{state | dave_session: session}, [Payload.mls_key_package_payload(key_package)]}
  end
end
