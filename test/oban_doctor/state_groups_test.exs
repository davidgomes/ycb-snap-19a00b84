defmodule ObanDoctor.StateGroupsTest do
  use ExUnit.Case, async: true

  alias ObanDoctor.StateGroups

  test "names/0 lists the Oban unique state groups" do
    assert StateGroups.names() == [:all, :incomplete, :scheduled, :successful]
  end

  test "states/1 mirrors Oban.Job.unique_states/1" do
    assert StateGroups.states(:incomplete) == [
             :suspended,
             :available,
             :scheduled,
             :executing,
             :retryable
           ]

    assert StateGroups.states(:scheduled) == [:scheduled]
    assert :completed in StateGroups.states(:successful)
    refute :discarded in StateGroups.states(:successful)
    assert :cancelled in StateGroups.states(:all)
  end

  test "group?/1 recognizes only named groups" do
    assert StateGroups.group?(:incomplete)
    refute StateGroups.group?(:completed)
    refute StateGroups.group?("all")
  end

  test "groups_in_list/1 finds group-only atoms embedded in a state list" do
    assert StateGroups.groups_in_list([:available, :all]) == [:all]
    assert StateGroups.groups_in_list([:incomplete]) == [:incomplete]
    assert StateGroups.groups_in_list([:available, :scheduled]) == []
    assert StateGroups.groups_in_list(:incomplete) == []
  end

  test "doc helpers point at the Oban unique jobs docs" do
    assert StateGroups.doc_url() == "https://oban.hexdocs.pm/unique_jobs.html"

    assert StateGroups.unique_states_doc_url() ==
             "https://oban.hexdocs.pm/Oban.Job.html#unique_states/1"
  end
end
