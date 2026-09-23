defmodule Nostrum.Voice.Event do
  @moduledoc false

  alias Nostrum.Cache.UserCache
  alias Nostrum.Constants
  alias Nostrum.Struct.VoiceWSState
  alias Nostrum.Voice
  alias Nostrum.Voice.Audio
  alias Nostrum.Voice.Crypto
  alias Nostrum.Voice.E2EE
  alias Nostrum.Voice.Payload
  alias Nostrum.Voice.Session

  require Logger

  @type reply :: VoiceWSState.t() | {VoiceWSState.t(), :gun.ws_frame() | [:gun.ws_frame()]}

  @spec handle(map(), VoiceWSState.t()) :: reply()
  def handle(payload, state) do
    state = update_sequence(state, payload)

    payload["op"]
    |> Constants.atom_from_voice_opcode()
    |> handle_event(payload, state)
  end

  @spec handle_binary(binary(), VoiceWSState.t()) :: reply()
  def handle_binary(<<seq::16, opcode::8, payload::binary>>, state) do
    opcode
    |> Constants.atom_from_voice_opcode()
    |> handle_event(payload, %{state | seq: seq})
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

    {state, frames} =
      E2EE.init(%{state | secret_key: secret_key}, payload["d"]["dave_protocol_version"] || 0)

    Voice.update_voice_async(state.voice_pid, state.guild_id,
      secret_key: secret_key,
      rtp_sequence: 0,
      rtp_timestamp: 0
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
      {state, {:text, Payload.resume_payload(state)}}
    else
      Logger.info("IDENTIFYING")
      {%{state | identified: true}, {:text, Payload.identify_payload(state)}}
    end
  end

  defp handle_event(:clients_connect, payload, state) do
    user_ids = Enum.map(payload["d"]["user_ids"], &String.to_integer/1)

    Logger.debug(fn ->
      "Voice clients connected: #{Enum.map_join(user_ids, ", ", &username/1)}"
    end)

    %{state | connected_user_ids: MapSet.union(state.connected_user_ids, MapSet.new(user_ids))}
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

    %{state | connected_user_ids: MapSet.delete(state.connected_user_ids, user_id)}
  end

  defp handle_event(:codec_info, _payload, state), do: state

  defp handle_event(:speaking, payload, state) do
    ssrc = payload["d"]["ssrc"]
    user_id = payload["d"]["user_id"] |> String.to_integer()
    ssrc_map = Map.put(state.ssrc_map, ssrc, user_id)
    %{state | ssrc_map: ssrc_map}
  end

  defp handle_event(:dave_prepare_transition, payload, state),
    do: E2EE.prepare_transition(state, payload["d"])

  defp handle_event(:dave_execute_transition, payload, state),
    do: E2EE.execute_transition(state, payload["d"]["transition_id"])

  defp handle_event(:dave_prepare_epoch, payload, state),
    do: E2EE.prepare_epoch(state, payload["d"])

  defp handle_event(:dave_mls_external_sender, payload, state),
    do: E2EE.set_external_sender(state, payload)

  defp handle_event(:dave_mls_proposals, payload, state),
    do: E2EE.process_proposals(state, payload)

  defp handle_event(:dave_mls_announce_commit_transition, payload, state),
    do: E2EE.process_commit(state, payload)

  defp handle_event(:dave_mls_welcome, payload, state),
    do: E2EE.process_welcome(state, payload)

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
end
