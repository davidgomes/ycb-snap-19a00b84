defmodule Nostrum.Voice.Event do
  @moduledoc false

  alias Nostrum.Cache.UserCache
  alias Nostrum.Constants
  alias Nostrum.Struct.VoiceWSState
  alias Nostrum.Voice
  alias Nostrum.Voice.Audio
  alias Nostrum.Voice.Crypto
  alias Nostrum.Voice.Crypto.Dave
  alias Nostrum.Voice.Payload
  alias Nostrum.Voice.Session

  require Logger

  @spec handle(map(), VoiceWSState.t()) ::
          VoiceWSState.t() | {VoiceWSState.t(), Dave.frame() | [Dave.frame()]}
  def handle(payload, state) do
    state = update_sequence(state, payload)

    payload["op"]
    |> Constants.atom_from_voice_opcode()
    |> handle_event(payload, state)
  end

  @spec handle_binary(binary(), VoiceWSState.t()) ::
          VoiceWSState.t() | {VoiceWSState.t(), [Dave.frame()]}
  def handle_binary(<<seq::16, opcode::8, payload::binary>>, state) do
    opcode
    |> Constants.atom_from_voice_opcode()
    |> handle_binary_event(payload, %{state | seq: seq})
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

    {%{state | encryption_mode: mode},
     {:text, Payload.select_protocol_payload(my_ip, my_port, mode)}}
  end

  defp handle_event(:session_description, payload, state) do
    Logger.debug("VOICE SESSION DESCRIPTION")

    secret_key = payload["d"]["secret_key"] |> :erlang.list_to_binary()
    dave_protocol_version = payload["d"]["dave_protocol_version"] || 0

    {state, frames} =
      Dave.reinit(%{state | secret_key: secret_key, dave_protocol_version: dave_protocol_version})

    Voice.update_voice_async(state.voice_pid, state.guild_id,
      secret_key: secret_key,
      rtp_sequence: 0,
      rtp_timestamp: 0,
      dave_session: state.dave_session,
      dave_protocol_version: dave_protocol_version
    )

    Session.on_voice_ready(state.conn_pid)

    reply(state, frames)
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
      {state, {:text, Payload.resume_payload(state)}}
    else
      Logger.info("IDENTIFYING")
      {%{state | identified: true}, {:text, Payload.identify_payload(state)}}
    end
  end

  defp handle_event(:clients_connect, payload, state) do
    user_ids = payload["d"]["user_ids"] |> Enum.map(&String.to_integer/1)

    %{state | connected_users: MapSet.union(state.connected_users, MapSet.new(user_ids))}
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

  defp handle_event(:client_disconnect, payload, state) do
    user_id = payload["d"]["user_id"] |> String.to_integer()

    Logger.debug(fn ->
      "Voice client disconnected: #{case UserCache.get(user_id) do
        {:ok, %{username: username}} -> username
        _ -> user_id
      end}"
    end)

    %{state | connected_users: MapSet.delete(state.connected_users, user_id)}
  end

  defp handle_event(:codec_info, _payload, state), do: state

  defp handle_event(:speaking, payload, state) do
    ssrc = payload["d"]["ssrc"]
    user_id = payload["d"]["user_id"] |> String.to_integer()
    ssrc_map = Map.put(state.ssrc_map, ssrc, user_id)
    %{state | ssrc_map: ssrc_map}
  end

  defp handle_event(:dave_protocol_prepare_transition, payload, state) do
    Logger.debug("VOICE DAVE PREPARE TRANSITION")

    %{"transition_id" => transition_id, "protocol_version" => protocol_version} = payload["d"]

    state
    |> Dave.prepare_transition(transition_id, protocol_version)
    |> sync_dave(state)
  end

  defp handle_event(:dave_protocol_execute_transition, payload, state) do
    Logger.debug("VOICE DAVE EXECUTE TRANSITION")

    {Dave.execute_transition(state, payload["d"]["transition_id"]), []}
    |> sync_dave(state)
  end

  defp handle_event(:dave_protocol_prepare_epoch, payload, state) do
    Logger.debug("VOICE DAVE PREPARE EPOCH")

    %{"epoch" => epoch, "protocol_version" => protocol_version} = payload["d"]

    state
    |> Dave.prepare_epoch(epoch, protocol_version)
    |> sync_dave(state)
  end

  defp handle_event(event, _payload, state) do
    Logger.debug("UNHANDLED VOICE GATEWAY EVENT #{event}")
    state
  end

  defp handle_binary_event(:dave_mls_external_sender_package, payload, state) do
    Logger.debug("VOICE DAVE MLS EXTERNAL SENDER PACKAGE")
    Dave.set_external_sender(state, payload)
  end

  defp handle_binary_event(:dave_mls_proposals, payload, state) do
    Logger.debug("VOICE DAVE MLS PROPOSALS")

    state
    |> Dave.process_proposals(payload)
    |> sync_dave(state)
  end

  defp handle_binary_event(:dave_mls_announce_commit_transition, payload, state) do
    Logger.debug("VOICE DAVE MLS ANNOUNCE COMMIT TRANSITION")

    state
    |> Dave.process_commit(payload)
    |> sync_dave(state)
  end

  defp handle_binary_event(:dave_mls_welcome, payload, state) do
    Logger.debug("VOICE DAVE MLS WELCOME")

    state
    |> Dave.process_welcome(payload)
    |> sync_dave(state)
  end

  defp handle_binary_event(event, _payload, state) do
    Logger.debug("UNHANDLED VOICE GATEWAY BINARY EVENT #{event}")
    state
  end

  # The voice state is where audio is encrypted before being sent, so it must be
  # kept in sync with any change to the DAVE session or protocol version in effect
  defp sync_dave(
         {%{dave_session: session, dave_protocol_version: version} = state, frames},
         %{dave_session: session, dave_protocol_version: version} = _old_state
       ),
       do: reply(state, frames)

  defp sync_dave({state, frames}, _old_state) do
    Voice.update_voice_async(state.voice_pid, state.guild_id,
      dave_session: state.dave_session,
      dave_protocol_version: state.dave_protocol_version
    )

    reply(state, frames)
  end

  defp reply(state, []), do: state
  defp reply(state, frames), do: {state, frames}
end
