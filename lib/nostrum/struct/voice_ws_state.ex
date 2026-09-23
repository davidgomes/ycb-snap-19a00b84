defmodule Nostrum.Struct.VoiceWSState do
  @moduledoc """
  Struct representing the current Voice WS state.
  """

  defstruct [
    :guild_id,
    :channel_id,
    :ssrc_map,
    :session,
    :token,
    :secret_key,
    :conn,
    :conn_pid,
    :voice_pid,
    :stream,
    :gateway,
    :identified,
    :seq,
    :encryption_mode,
    :last_heartbeat_send,
    :last_heartbeat_ack,
    :heartbeat_ack,
    :heartbeat_interval,
    :heartbeat_ref,
    :bot_options,
    :dave_session,
    :dave_protocol_version,
    :dave_pending_transitions,
    :dave_downgraded,
    :connected_users
  ]

  @typedoc "The guild id that this voice websocket state applies to"
  @type guild_id :: Nostrum.Struct.Guild.id()

  @typedoc "The channel id that this voice websocket state applies to"
  @typedoc since: "0.6.0"
  @type channel_id :: Nostrum.Struct.Channel.id()

  @typedoc """
  A mapping of RTP SSRC (synchronization source) to user id

  This map can be used to identify the user who generated the incoming
  audio data when an RTP packet is received.
  """
  @typedoc since: "0.6.0"
  @type ssrc_map :: %{integer() => Nostrum.Struct.User.id()}

  @typedoc "The session id"
  @type session :: String.t()

  @typedoc "The session token"
  @type token :: String.t()

  @typedoc "The secret key for audio encryption"
  @typedoc since: "0.6.0"
  @type secret_key :: binary() | nil

  @typedoc "PID of the `:gun` worker connected to the websocket"
  @type conn :: pid()

  @typedoc "PID of the connection process"
  @type conn_pid :: pid()

  @typedoc "PID of the voice state map"
  @type voice_pid :: pid()

  @typedoc "Stream reference for `:gun`"
  @type stream :: :gun.stream_ref()

  @typedoc "Gateway URL"
  @type gateway :: String.t()

  @typedoc "Whether the session has been identified"
  @type identified :: boolean()

  @typedoc "Sequence number for buffering server-sent events"
  @type seq :: integer()

  @typedoc "Encryption mode selected for voice channel"
  @type encryption_mode :: Nostrum.Voice.Crypto.cipher()

  @typedoc """
  The time the last heartbeat was sent, if a heartbeat hasn't been sent it
  will be the time the websocket process was started
  """
  @type last_heartbeat_send :: DateTime.t()

  @typedoc """
  The time the last heartbeat was acknowledged, will be nil if a heartbeat
  hasn't been ACK'd yet
  """
  @type last_heartbeat_ack :: DateTime.t() | nil

  @typedoc "Whether or not the last heartbeat sent was ACK'd"
  @type heartbeat_ack :: boolean()

  @typedoc "Interval at which heartbeats are sent"
  @type heartbeat_interval :: integer() | nil

  @typedoc "Time ref for the heartbeat"
  @type heartbeat_ref :: :timer.tref() | nil

  @typedoc "DAVE (end-to-end encryption) session, `nil` until negotiated"
  @typedoc since: "0.11.0"
  @type dave_session :: Dave.session() | nil

  @typedoc "Negotiated DAVE protocol version, `0` if end-to-end encryption is not in use"
  @typedoc since: "0.11.0"
  @type dave_protocol_version :: non_neg_integer()

  @typedoc "Pending DAVE transitions mapping transition id to protocol version"
  @typedoc since: "0.11.0"
  @type dave_pending_transitions :: %{non_neg_integer() => non_neg_integer()}

  @typedoc "Whether the DAVE session was downgraded to unencrypted media"
  @typedoc since: "0.11.0"
  @type dave_downgraded :: boolean()

  @typedoc "User ids of other clients connected to the voice channel"
  @typedoc since: "0.11.0"
  @type connected_users :: MapSet.t(Nostrum.Struct.User.id())

  @type t :: %__MODULE__{
          guild_id: guild_id,
          channel_id: channel_id,
          ssrc_map: ssrc_map,
          session: session,
          token: token,
          secret_key: secret_key,
          conn: conn,
          conn_pid: conn_pid,
          voice_pid: voice_pid,
          stream: stream,
          gateway: gateway,
          identified: identified,
          seq: seq,
          encryption_mode: encryption_mode,
          last_heartbeat_send: last_heartbeat_send,
          last_heartbeat_ack: last_heartbeat_ack,
          heartbeat_ack: heartbeat_ack,
          heartbeat_interval: heartbeat_interval,
          heartbeat_ref: heartbeat_ref,
          bot_options: Nostrum.Bot.bot_options(),
          dave_session: dave_session,
          dave_protocol_version: dave_protocol_version,
          dave_pending_transitions: dave_pending_transitions,
          dave_downgraded: dave_downgraded,
          connected_users: connected_users
        }
end
