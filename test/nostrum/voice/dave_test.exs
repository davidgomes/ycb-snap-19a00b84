defmodule Nostrum.Voice.DaveTest do
  alias Nostrum.Struct.VoiceWSState
  alias Nostrum.Voice.Crypto.Dave
  alias Nostrum.Voice.Event
  alias Nostrum.Voice.Payload

  use ExUnit.Case, async: true

  @moduletag :capture_log

  @opus_silence <<0xF8, 0xFF, 0xFE>>

  setup do
    state = %VoiceWSState{
      guild_id: 1,
      channel_id: 2,
      voice_pid: self(),
      seq: -1,
      connected_users: MapSet.new(),
      dave_protocol_version: 0
    }

    %{state: state}
  end

  describe "transitions" do
    test "transition id 0 is executed immediately", %{state: state} do
      {state, []} = Dave.prepare_transition(state, 0, 1)

      assert state.dave_protocol_version == 1
      assert is_nil(state.dave_pending_transition)
    end

    test "nonzero transition is deferred until executed", %{state: state} do
      {state, [{:text, ready}]} = Dave.prepare_transition(state, 7, 1)

      assert %{"op" => 23, "d" => %{"transition_id" => 7}} = decode(ready)
      assert state.dave_protocol_version == 0

      state = Dave.execute_transition(state, 7)

      assert state.dave_protocol_version == 1
      assert is_nil(state.dave_pending_transition)
    end

    test "executing an unannounced transition is ignored", %{state: state} do
      {state, _frames} = Dave.prepare_transition(state, 7, 1)
      state = Dave.execute_transition(state, 8)

      assert state.dave_protocol_version == 0
      assert is_nil(state.dave_pending_transition)
    end

    test "epochs other than 1 do not reinitialize", %{state: state} do
      assert {^state, []} = Dave.prepare_epoch(state, 2, 1)
    end
  end

  describe "without a DAVE session" do
    test "external sender is kept for later", %{state: state} do
      state = Dave.set_external_sender(state, "sender")
      assert state.dave_external_sender == "sender"
    end

    test "MLS messages are ignored", %{state: state} do
      assert {^state, []} = Dave.process_proposals(state, <<0, 1, 2>>)
      assert {^state, []} = Dave.process_commit(state, <<0, 1, 2>>)
      assert {^state, []} = Dave.process_welcome(state, <<0, 1, 2>>)
    end

    test "frames pass through encryption unchanged", %{state: state} do
      assert Dave.encrypt(state, "opus") == "opus"
      assert Dave.encrypt(%{state | dave_protocol_version: 1}, "opus") == "opus"
    end

    test "unencrypted frames pass through decryption unchanged" do
      assert Dave.decrypt(nil, 123, "opus") == {:ok, "opus"}
      assert Dave.decrypt(nil, nil, @opus_silence) == {:ok, @opus_silence}
    end

    test "DAVE frames cannot be decrypted" do
      assert Dave.decrypt(nil, 123, <<1, 2, 3, 0xFA, 0xFA>>) == :error
    end
  end

  describe "with a DAVE session" do
    setup %{state: state} do
      session = Elixir.Dave.new_session(1, 100, state.channel_id)
      %{state: %{state | dave_session: session, dave_protocol_version: 1}}
    end

    test "frames are sent unencrypted until the session is ready", %{state: state} do
      refute Elixir.Dave.ready?(state.dave_session)
      assert Dave.encrypt(state, "opus") == "opus"
    end

    test "silence is never encrypted", %{state: state} do
      assert Dave.encrypt(state, @opus_silence) == @opus_silence
    end

    test "DAVE frames from unknown users fail decryption", %{state: state} do
      assert Dave.decrypt(state.dave_session, 123, <<1, 2, 3, 0xFA, 0xFA>>) == :error
      assert Dave.decrypt(state.dave_session, nil, <<1, 2, 3, 0xFA, 0xFA>>) == :error
    end

    test "invalid proposals produce no reply", %{state: state} do
      assert {^state, []} = Dave.process_proposals(state, <<0, 1, 2>>)
    end

    test "invalid commit requests removal and re-addition", %{state: state} do
      {_state, [{:text, invalid} | _key_package]} =
        Dave.process_commit(%{state | dave_protocol_version: 0}, <<0, 9, 1, 2, 3>>)

      assert %{"op" => 31, "d" => %{"transition_id" => 9}} = decode(invalid)
    end
  end

  describe "voice gateway events" do
    test "binary messages update the sequence number", %{state: state} do
      state = Event.handle_binary(<<0, 42, 25, "sender">>, state)

      assert state.seq == 42
      assert state.dave_external_sender == "sender"
    end

    test "connected users are tracked", %{state: state} do
      state = Event.handle(%{"op" => 11, "d" => %{"user_ids" => ["10", "20"]}}, state)

      assert state.connected_users == MapSet.new([10, 20])
    end

    test "executed transitions are synced to the voice state", %{state: state} do
      payload = %{"op" => 21, "d" => %{"transition_id" => 0, "protocol_version" => 1}}
      state = Event.handle(payload, state)

      assert state.dave_protocol_version == 1
      assert_received {:"$gen_cast", {:update, 1, update}}
      assert update[:dave_protocol_version] == 1
    end
  end

  describe "payloads" do
    test "client binary messages are prefixed with only the opcode" do
      assert IO.iodata_to_binary(Payload.dave_mls_key_package_payload("kp")) == <<26, "kp">>

      assert IO.iodata_to_binary(Payload.dave_mls_commit_welcome_payload("c", "w")) ==
               <<28, "cw">>

      assert IO.iodata_to_binary(Payload.dave_mls_commit_welcome_payload("c", nil)) ==
               <<28, "c">>
    end
  end

  defp decode(payload), do: payload |> IO.iodata_to_binary() |> Jason.decode!()
end
