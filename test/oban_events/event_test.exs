defmodule ObanEvents.EventTest do
  use ExUnit.Case, async: true

  alias ObanEvents.Event

  describe "new/3" do
    test "builds an event struct with generated id and timestamp" do
      event = Event.new(:user_created, %{"user_id" => 1})

      assert event.name == :user_created
      assert event.data == %{"user_id" => 1}
      assert event.metadata == %{}
      assert {:ok, _} = Ecto.UUID.cast(event.id)
      assert %DateTime{} = event.emitted_at
    end

    test "accepts custom metadata" do
      event = Event.new(:user_created, %{"user_id" => 1}, %{source: "api"})

      assert event.metadata == %{source: "api"}
    end
  end
end
