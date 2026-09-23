defmodule Nostrum.Voice.E2EETest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Nostrum.Bot
  alias Nostrum.Cache.Me
  alias Nostrum.Cache.UserCache
  alias Nostrum.Struct.User
  alias Nostrum.Struct.VoiceState
  alias Nostrum.Struct.VoiceWSState
  alias Nostrum.Voice.E2EE
  alias Nostrum.Voice.Event
  alias Nostrum.Voice.Session

  @user_id 1_234
  @guild_id 5_678
  @channel_id 9_012
  @ssrc 42

  setup do
    cache = %{
      id: Nostrum.Cache.Supervisor,
      type: :supervisor,
      start: {Supervisor, :start_link, [[Me], [strategy: :one_for_one]]}
    }

    bot =
      start_supervised!(%{
        id: :bot,
        type: :supervisor,
        start: {Supervisor, :start_link, [[cache], [strategy: :one_for_one]]}
      })

    Bot.set_bot_pid(bot)
    Me.put(%User{id: @user_id})

    state = %VoiceWSState{
      guild_id: @guild_id,
      channel_id: @channel_id,
      voice_pid: self(),
      ssrc_map: %{},
      connected_user_ids: MapSet.new(),
      dave_session: E2EE.new_session(@channel_id),
      dave_protocol_version: 0,
      dave_pending_transitions: %{}
    }

    %{state: state}
  end

  defp decode({:text, payload}), do: payload |> IO.iodata_to_binary() |> Jason.decode!()

  describe "init/2" do
    test "sends a key package when the DAVE protocol is in effect", %{state: state} do
      {state, [{:binary, [26, key_package]}]} = E2EE.init(state, 1)

      assert state.dave_protocol_version == 1
      assert byte_size(key_package) > 0

      assert_receive {:"$gen_cast", {:update, @guild_id, update}}
      assert update[:dave_session] == state.dave_session
      assert update[:dave_protocol_version] == 1
    end

    test "sends nothing when the DAVE protocol is not in effect", %{state: state} do
      assert {%VoiceWSState{dave_protocol_version: 0}, []} = E2EE.init(state, 0)
    end
  end

  describe "transitions" do
    test "are acknowledged when prepared and applied when executed", %{state: state} do
      payload = %{"transition_id" => 3, "protocol_version" => 1}
      {state, [ready]} = E2EE.prepare_transition(state, payload)

      assert %{"op" => 23, "d" => %{"transition_id" => 3}} = decode(ready)
      assert state.dave_pending_transitions == %{3 => 1}
      assert state.dave_protocol_version == 0

      state = E2EE.execute_transition(state, 3)

      assert state.dave_pending_transitions == %{}
      assert state.dave_protocol_version == 1
      assert_receive {:"$gen_cast", {:update, @guild_id, update}}
      assert update[:dave_protocol_version] == 1
    end

    test "with id 0 are executed immediately", %{state: state} do
      payload = %{"transition_id" => 0, "protocol_version" => 1}

      assert {%VoiceWSState{dave_protocol_version: 1, dave_pending_transitions: pending}, []} =
               E2EE.prepare_transition(state, payload)

      assert pending == %{}
    end

    test "that are unknown are not executed", %{state: state} do
      assert ^state = E2EE.execute_transition(state, 5)
      refute_receive {:"$gen_cast", _}
    end
  end

  describe "prepare_epoch/2" do
    test "sends a new key package for a new MLS group", %{state: state} do
      payload = %{"epoch" => 1, "protocol_version" => 1, "transition_id" => 4}

      assert {%VoiceWSState{dave_protocol_version: 1}, [{:binary, [26, _key_package]}]} =
               E2EE.prepare_epoch(state, payload)
    end

    test "does nothing for later epochs", %{state: state} do
      payload = %{"epoch" => 2, "protocol_version" => 1, "transition_id" => 4}

      assert {^state, []} = E2EE.prepare_epoch(state, payload)
    end
  end

  describe "MLS messages" do
    setup %{state: state} do
      {state, _frames} = E2EE.init(state, 1)
      %{state: state}
    end

    test "invalid commits and welcomes request to be re-added", %{state: state} do
      for process <- [&E2EE.process_commit/2, &E2EE.process_welcome/2] do
        log =
          capture_log(fn ->
            assert {_state, [invalid, {:binary, [26, _key_package]}]} =
                     process.(state, <<7::16, "invalid">>)

            assert %{"op" => 31, "d" => %{"transition_id" => 7}} = decode(invalid)
          end)

        assert log =~ "transition 7"
      end
    end

    test "invalid proposals are ignored", %{state: state} do
      log =
        capture_log(fn ->
          assert {^state, []} = E2EE.process_proposals(state, <<0, "invalid">>)
        end)

      assert log =~ "proposals"
    end

    test "replies to binary messages are sent over the websocket", %{state: state} do
      state = %{state | conn: self()}
      message = {:gun_ws, self(), :stream, {:binary, <<3::16, 29, 7::16, "invalid">>}}

      capture_log(fn ->
        assert {:noreply, %VoiceWSState{seq: 3}} = Session.handle_info(message, state)
      end)

      assert_receive {:"$gen_cast", {:ws_send, _pid, :stream, [{:text, _}, {:binary, [26, _]}]}}

      message = {:gun_ws, self(), :stream, {:binary, <<4::16, 25, "invalid">>}}

      capture_log(fn ->
        assert {:noreply, %VoiceWSState{seq: 4}} = Session.handle_info(message, state)
      end)

      refute_receive {:"$gen_cast", {:ws_send, _pid, _stream, _frames}}
    end

    test "invalid external senders are ignored", %{state: state} do
      log =
        capture_log(fn ->
          assert {new_state, []} = Event.handle_binary(<<9::16, 25, "invalid">>, state)
          assert new_state == %{state | seq: 9}
        end)

      assert log =~ "external sender"
    end
  end

  describe "encrypt/2" do
    test "leaves frames as-is when the DAVE protocol is not in effect", %{state: state} do
      voice = %VoiceState{dave_session: state.dave_session, dave_protocol_version: 0}
      assert E2EE.encrypt(voice, "opus") == "opus"
      assert E2EE.encrypt(%VoiceState{}, "opus") == "opus"
    end

    test "leaves frames as-is until the MLS group is established", %{state: state} do
      voice = %VoiceState{dave_session: state.dave_session, dave_protocol_version: 1}
      assert E2EE.encrypt(voice, "opus") == "opus"
    end
  end

  describe "decrypt/3" do
    test "leaves frames as-is when the DAVE protocol is not in effect", %{state: state} do
      assert E2EE.decrypt(state, @ssrc, "opus") == "opus"
    end

    test "leaves silence frames as-is", %{state: state} do
      state = %{state | dave_protocol_version: 1}
      silence = <<0xF8, 0xFF, 0xFE>>
      assert E2EE.decrypt(state, @ssrc, silence) == silence
    end

    test "fails for unknown senders", %{state: state} do
      state = %{state | dave_protocol_version: 1}
      assert E2EE.decrypt(state, @ssrc, "opus") == :error

      state = %{state | ssrc_map: %{@ssrc => 111}}
      assert E2EE.decrypt(state, @ssrc, "opus") == :error
    end
  end

  describe "Event.handle/2" do
    test "tracks connected clients", %{state: state} do
      Bot.set_bot_name(__MODULE__)
      _tid = :ets.new(UserCache.ETS.table(), [:set, :public, :named_table])

      state = Event.handle(%{"op" => 11, "d" => %{"user_ids" => ["111", "222"]}}, state)
      assert state.connected_user_ids == MapSet.new([111, 222])

      state = Event.handle(%{"op" => 13, "d" => %{"user_id" => "111"}}, state)
      assert state.connected_user_ids == MapSet.new([222])
    end
  end
end
