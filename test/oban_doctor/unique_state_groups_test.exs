defmodule ObanDoctor.UniqueStateGroupsTest do
  use ExUnit.Case, async: true

  alias ObanDoctor.UniqueStateGroups

  describe "group_name/1" do
    test "recognizes Oban named state groups" do
      assert UniqueStateGroups.group_name(:all) == :all
      assert UniqueStateGroups.group_name(:incomplete) == :incomplete
      assert UniqueStateGroups.group_name(:scheduled) == :scheduled
      assert UniqueStateGroups.group_name(:successful) == :successful
    end

    test "recognizes a single-element list containing a group" do
      assert UniqueStateGroups.group_name([:incomplete]) == :incomplete
    end

    test "returns nil for explicit state lists and unknown atoms" do
      assert UniqueStateGroups.group_name([:available, :scheduled]) == nil
      assert UniqueStateGroups.group_name(:available) == nil
      assert UniqueStateGroups.group_name(nil) == nil
    end
  end

  describe "expand/1" do
    test "expands groups to the states defined by Oban.Job.unique_states/1" do
      assert UniqueStateGroups.expand(:incomplete) == [
               :suspended,
               :available,
               :scheduled,
               :executing,
               :retryable
             ]

      assert UniqueStateGroups.expand(:scheduled) == [:scheduled]

      assert :completed in UniqueStateGroups.expand(:successful)
      refute :discarded in UniqueStateGroups.expand(:successful)
      refute :cancelled in UniqueStateGroups.expand(:successful)

      assert :discarded in UniqueStateGroups.expand(:all)
      assert :cancelled in UniqueStateGroups.expand(:all)
    end

    test "expands a single-element group list and leaves explicit lists unchanged" do
      assert UniqueStateGroups.expand([:successful]) == UniqueStateGroups.expand(:successful)
      assert UniqueStateGroups.expand([:available, :executing]) == [:available, :executing]
    end
  end

  describe "documentation references" do
    test "points at Oban's unique state group docs" do
      assert UniqueStateGroups.unique_states_url() ==
               "https://hexdocs.pm/oban/Oban.Job.html#unique_states/1"

      assert UniqueStateGroups.unique_jobs_url() == "https://hexdocs.pm/oban/unique_jobs.html"

      assert UniqueStateGroups.upgrade_url() ==
               "https://hexdocs.pm/oban/v2-20.html#update-unique-states-optional"
    end
  end
end
