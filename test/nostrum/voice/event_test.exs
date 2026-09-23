defmodule Nostrum.Voice.EventTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Nostrum.Struct.VoiceWSState
  alias Nostrum.Voice.Event

  @moduletag :capture_log

  @guild_id 1234
  @channel_id 5678
  @user_id 42

  setup do
    # Debug messages look up users in the cache, which requires a running bot
    Logger.put_module_level(Event, :info)
    on_exit(fn -> Logger.delete_module_level(Event) end)

    state = %VoiceWSState{
      guild_id: @guild_id,
      channel_id: @channel_id,
      voice_pid: self(),
      ssrc_map: %{},
      seq: -1,
      dave_session: Dave.new_session(1, @user_id, @channel_id),
      dave_protocol_version: 1,
      dave_pending_transitions: %{},
      dave_connected_users: MapSet.new()
    }

    %{state: state}
  end

  defp decode_text_frame({:text, iodata}), do: iodata |> IO.iodata_to_binary() |> Jason.decode!()

  describe "clients connecting" do
    test "clients connect adds users to the connected users", %{state: state} do
      payload = %{"op" => 11, "d" => %{"user_ids" => ["1", "2"]}}

      %VoiceWSState{dave_connected_users: users} = Event.handle(payload, state)

      assert users == MapSet.new([1, 2])
    end

    test "client disconnect removes the user from the connected users", %{state: state} do
      state = %{state | dave_connected_users: MapSet.new([1, 2])}
      payload = %{"op" => 13, "d" => %{"user_id" => "1"}}

      %VoiceWSState{dave_connected_users: users} = Event.handle(payload, state)

      assert users == MapSet.new([2])
    end
  end

  describe "DAVE protocol transitions" do
    test "downgrade is acknowledged and executed", %{state: state} do
      prepare = %{"op" => 21, "d" => %{"transition_id" => 7, "protocol_version" => 0}}

      {state, reply} = Event.handle(prepare, state)

      assert state.dave_pending_transitions == %{7 => 0}
      assert %{"op" => 23, "d" => %{"transition_id" => 7}} = decode_text_frame(reply)
      refute_received {:"$gen_cast", _}

      execute = %{"op" => 22, "d" => %{"transition_id" => 7}}

      state = Event.handle(execute, state)

      assert state.dave_protocol_version == 0
      assert state.dave_pending_transitions == %{}
      assert_received {:"$gen_cast", {:update, @guild_id, [dave_session: nil]}}
    end

    test "transition id 0 is executed immediately", %{state: state} do
      state = %{state | dave_protocol_version: 0}
      prepare = %{"op" => 21, "d" => %{"transition_id" => 0, "protocol_version" => 1}}

      state = Event.handle(prepare, state)

      assert state.dave_protocol_version == 1
      assert state.dave_pending_transitions == %{}
      session = state.dave_session
      assert_received {:"$gen_cast", {:update, @guild_id, [dave_session: ^session]}}
    end

    test "executing an unknown transition does nothing", %{state: state} do
      execute = %{"op" => 22, "d" => %{"transition_id" => 3}}

      assert Event.handle(execute, state) == state
      refute_received {:"$gen_cast", _}
    end

    test "prepare epoch for an existing group does nothing", %{state: state} do
      prepare = %{"op" => 24, "d" => %{"epoch" => 2, "protocol_version" => 1}}

      assert Event.handle(prepare, state) == state
    end
  end

  describe "DAVE MLS binary messages" do
    test "sequence number is tracked", %{state: state} do
      payload = %{"seq" => 12, "op" => 27, "d" => <<0, 1, 2, 3>>}

      log = capture_log(fn -> assert %VoiceWSState{seq: 12} = Event.handle(payload, state) end)

      assert log =~ "Failed to process DAVE MLS proposals"
    end

    test "invalid external sender is ignored", %{state: state} do
      payload = %{"seq" => 1, "op" => 25, "d" => <<1, 2, 3>>}

      log = capture_log(fn -> assert %VoiceWSState{} = Event.handle(payload, state) end)

      assert log =~ "Failed to set DAVE MLS external sender"
    end

    test "invalid commit is reported", %{state: state} do
      state = %{state | dave_protocol_version: 0}
      payload = %{"seq" => 1, "op" => 29, "d" => <<0, 9, 1, 2, 3>>}

      {_state, [reply]} = Event.handle(payload, state)

      assert %{"op" => 31, "d" => %{"transition_id" => 9}} = decode_text_frame(reply)
    end

    test "invalid welcome is reported", %{state: state} do
      state = %{state | dave_protocol_version: 0}
      payload = %{"seq" => 1, "op" => 30, "d" => <<0, 4, 1, 2, 3>>}

      {_state, [reply]} = Event.handle(payload, state)

      assert %{"op" => 31, "d" => %{"transition_id" => 4}} = decode_text_frame(reply)
    end
  end
end
