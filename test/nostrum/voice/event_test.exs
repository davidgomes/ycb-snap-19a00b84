defmodule Nostrum.Voice.EventTest do
  use ExUnit.Case, async: true

  alias Nostrum.Bot
  alias Nostrum.Cache.Me
  alias Nostrum.Cache.TestBase
  alias Nostrum.Cache.UserCache
  alias Nostrum.Struct.User
  alias Nostrum.Struct.VoiceWSState
  alias Nostrum.Voice.Crypto
  alias Nostrum.Voice.Event

  @moduletag :capture_log

  @guild_id 100
  @channel_id 200
  @alice 300
  @bob 400

  setup do
    # Debug log messages look up usernames in the user cache
    TestBase.setup_and_teardown_cache(UserCache.ETS)

    cache_supervisor = %{
      id: Nostrum.Cache.Supervisor,
      type: :supervisor,
      start: {Supervisor, :start_link, [[{Me, []}], [strategy: :one_for_one]]}
    }

    bot = %{
      id: :bot,
      type: :supervisor,
      start: {Supervisor, :start_link, [[cache_supervisor], [strategy: :one_for_one]]}
    }

    Bot.set_bot_pid(start_supervised!(bot))
    as_user(@alice)

    state = %VoiceWSState{
      guild_id: @guild_id,
      channel_id: @channel_id,
      conn_pid: self(),
      voice_pid: self(),
      ssrc_map: %{},
      connected_users: MapSet.new(),
      seq: -1,
      dave_protocol_version: 0,
      dave_pending_transitions: %{},
      dave_downgraded: false
    }

    %{state: state}
  end

  defp as_user(user_id), do: Me.put(%User{id: user_id})

  defp text(op, data), do: %{"op" => op, "d" => data}

  defp binary(seq, op, data), do: %{"seq" => seq, "op" => op, "d" => data}

  defp decode({:text, json}), do: Jason.decode!(json)
  defp decode({:binary, data}), do: IO.iodata_to_binary(data)

  defp session_description(dave_protocol_version) do
    text(4, %{
      "mode" => "aead_aes256_gcm_rtpsize",
      "secret_key" => List.duplicate(7, 32),
      "dave_protocol_version" => dave_protocol_version
    })
  end

  defp assert_dave_session_update(session) do
    assert_receive {:"$gen_cast", {:update, @guild_id, args}}
    assert args[:dave_session] == session
  end

  describe "session description" do
    test "without DAVE only configures transport encryption", %{state: state} do
      assert {state, []} = Event.handle(session_description(0), state)

      assert state.secret_key == :binary.copy(<<7>>, 32)
      assert state.dave_session == nil
      assert_dave_session_update(nil)
      assert_receive {:"$gen_cast", :voice_ready}
    end

    test "with DAVE creates a session and sends a key package", %{state: state} do
      assert {state, [key_package]} = Event.handle(session_description(1), state)

      assert <<26, _key_package::binary>> = decode(key_package)
      assert state.dave_protocol_version == 1
      assert is_reference(state.dave_session)
      assert_dave_session_update(state.dave_session)
    end
  end

  describe "connected users" do
    test "are added and removed", %{state: state} do
      state = Event.handle(text(11, %{"user_ids" => ["1", "2"]}), state)
      assert state.connected_users == MapSet.new([1, 2])

      state = Event.handle(text(13, %{"user_id" => "1"}), state)
      assert state.connected_users == MapSet.new([2])
    end
  end

  describe "protocol transitions" do
    setup %{state: state} do
      %{state: %{state | dave_session: Dave.new_session(1, @alice, @channel_id)}}
    end

    test "are acknowledged and executed later", %{state: state} do
      prepare = text(21, %{"transition_id" => 5, "protocol_version" => 1})
      assert {state, ready} = Event.handle(prepare, state)

      assert decode(ready) == %{"op" => 23, "d" => %{"transition_id" => 5}}
      assert state.dave_pending_transitions == %{5 => 1}
      assert state.dave_protocol_version == 0

      state = Event.handle(text(22, %{"transition_id" => 5}), state)

      assert state.dave_pending_transitions == %{}
      assert state.dave_protocol_version == 1
      assert_dave_session_update(state.dave_session)
    end

    test "with id 0 are executed immediately", %{state: state} do
      state = %{state | dave_protocol_version: 1}
      state = Event.handle(text(21, %{"transition_id" => 0, "protocol_version" => 0}), state)

      assert state.dave_pending_transitions == %{}
      assert state.dave_protocol_version == 0
      assert state.dave_downgraded
      assert_dave_session_update(nil)
    end

    test "can downgrade and upgrade again", %{state: state} do
      state = %{state | dave_protocol_version: 1}

      {state, _ready} =
        Event.handle(text(21, %{"transition_id" => 1, "protocol_version" => 0}), state)

      state = Event.handle(text(22, %{"transition_id" => 1}), state)
      assert state.dave_protocol_version == 0
      assert state.dave_downgraded
      assert_dave_session_update(nil)

      {state, [key_package]} =
        Event.handle(text(24, %{"epoch" => 1, "protocol_version" => 1}), state)

      assert <<26, _key_package::binary>> = decode(key_package)
      assert state.dave_protocol_version == 1
      assert_dave_session_update(state.dave_session)

      {state, _ready} =
        Event.handle(text(21, %{"transition_id" => 2, "protocol_version" => 1}), state)

      state = Event.handle(text(22, %{"transition_id" => 2}), state)
      assert state.dave_protocol_version == 1
      refute state.dave_downgraded
    end

    test "that are unknown are ignored", %{state: state} do
      assert Event.handle(text(22, %{"transition_id" => 9}), state) == state
    end
  end

  describe "MLS messages" do
    test "update the sequence number", %{state: state} do
      state = Event.handle(binary(42, 27, <<0, 0>>), state)
      assert state.seq == 42
    end

    test "are ignored without a DAVE session", %{state: state} do
      assert Event.handle(binary(1, 29, <<1::16, "commit">>), state) == %{state | seq: 1}
    end

    test "invalid external senders don't raise", %{state: state} do
      state = Event.handle(binary(1, 25, "not an external sender"), state)
      assert is_reference(state.dave_session)
    end

    test "unprocessable commits request to be re-added", %{state: state} do
      {state, _key_package} = Event.handle(session_description(1), state)

      assert {_state, [invalid, key_package]} =
               Event.handle(binary(2, 29, <<3::16, "not a commit">>), state)

      assert decode(invalid) == %{"op" => 31, "d" => %{"transition_id" => 3}}
      assert <<26, _key_package::binary>> = decode(key_package)
    end
  end

  describe "end-to-end encryption" do
    test "is established between call members", %{state: state} do
      {external_sender, sign} = external_sender()

      # Both members connect to a call using DAVE
      {alice, [alice_key_package]} = Event.handle(session_description(1), state)
      alice = Event.handle(binary(1, 25, external_sender), alice)
      alice = Event.handle(text(11, %{"user_ids" => ["#{@bob}"]}), alice)

      as_user(@bob)
      {bob, [bob_key_package_frame]} = Event.handle(session_description(1), state)
      bob = Event.handle(binary(1, 25, external_sender), bob)
      bob = Event.handle(text(11, %{"user_ids" => ["#{@alice}"]}), bob)

      assert Dave.status(alice.dave_session) == :pending
      assert Dave.status(bob.dave_session) == :pending
      assert <<26, _::binary>> = decode(alice_key_package)
      assert {:binary, [26, bob_key_package]} = bob_key_package_frame

      # The voice gateway proposes adding Bob, and Alice commits the proposal
      proposal = external_add_proposal(bob_key_package, sign)
      proposals = <<0, vl_bytes(proposal)::binary>>

      assert {alice, {:binary, [28, [commit, welcome]]}} =
               Event.handle(binary(2, 27, proposals), alice)

      # Alice's commit wins, so Alice processes it and Bob is welcomed
      {alice, alice_ready} = Event.handle(binary(3, 29, <<1::16, commit::binary>>), alice)
      {bob, bob_ready} = Event.handle(binary(2, 30, <<1::16, welcome::binary>>), bob)

      assert decode(alice_ready) == %{"op" => 23, "d" => %{"transition_id" => 1}}
      assert decode(bob_ready) == %{"op" => 23, "d" => %{"transition_id" => 1}}

      alice = Event.handle(text(22, %{"transition_id" => 1}), alice)
      bob = Event.handle(text(22, %{"transition_id" => 1}), bob)

      alice_session = Crypto.active_dave_session(alice)
      bob_session = Crypto.active_dave_session(bob)
      assert Dave.ready?(alice_session)
      assert Dave.ready?(bob_session)

      opus = :crypto.strong_rand_bytes(100)

      encrypted = Crypto.dave_encrypt(alice_session, opus)
      assert <<_::binary-size(byte_size(encrypted) - 2), 0xFA, 0xFA>> = encrypted
      assert Crypto.dave_decrypt(bob_session, @alice, encrypted) == {:ok, opus}

      encrypted = Crypto.dave_encrypt(bob_session, opus)
      assert Crypto.dave_decrypt(alice_session, @bob, encrypted) == {:ok, opus}
    end
  end

  # The voice gateway is the MLS external sender that proposes adding and removing
  # members, see https://www.rfc-editor.org/rfc/rfc9420.html for the wire formats
  defp external_sender do
    {public_key, private_key} = :crypto.generate_key(:ecdh, :secp256r1)
    basic_credential = <<1::16, vl_bytes("voice gateway")::binary>>
    sign = &:crypto.sign(:ecdsa, :sha256, &1, [private_key, :secp256r1])

    {vl_bytes(public_key) <> basic_credential, sign}
  end

  defp external_add_proposal(key_package, sign) do
    mls10_public_message = <<1::16, 1::16>>
    external_sender_index_0 = <<2, 0::32>>
    add_proposal = <<2, 1::16, key_package::binary>>
    group_epoch = 0

    content =
      vl_bytes(<<@channel_id::64>>) <>
        <<group_epoch::64>> <>
        external_sender_index_0 <> vl_bytes(<<>>) <> add_proposal

    signature =
      sign.(vl_bytes("MLS 1.0 FramedContentTBS") <> vl_bytes(mls10_public_message <> content))

    mls10_public_message <> content <> vl_bytes(signature)
  end

  defp vl_bytes(data) when byte_size(data) < 0x40, do: <<byte_size(data), data::binary>>

  defp vl_bytes(data) when byte_size(data) < 0x4000,
    do: <<1::2, byte_size(data)::14, data::binary>>

  defp vl_bytes(data), do: <<2::2, byte_size(data)::30, data::binary>>
end
