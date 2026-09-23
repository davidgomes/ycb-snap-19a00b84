defmodule ObanDoctor.UniqueStateGroupsTest do
  use ExUnit.Case, async: true

  alias ObanDoctor.UniqueStateGroups

  test "lists the named groups from Oban.Job.unique_states/1" do
    assert UniqueStateGroups.groups() == [:all, :incomplete, :scheduled, :successful]
  end

  test "points at the Oban unique state docs" do
    assert UniqueStateGroups.doc_url() ==
             "https://hexdocs.pm/oban/Oban.Job.html#unique_states/1"

    assert UniqueStateGroups.guide_url() == "https://hexdocs.pm/oban/unique_jobs.html"
  end

  test "expands named groups to the states Oban checks" do
    assert UniqueStateGroups.expand(:all) == [
             :suspended,
             :scheduled,
             :available,
             :executing,
             :retryable,
             :completed,
             :discarded,
             :cancelled
           ]

    assert UniqueStateGroups.expand(:incomplete) == [
             :suspended,
             :available,
             :scheduled,
             :executing,
             :retryable
           ]

    assert UniqueStateGroups.expand(:scheduled) == [:scheduled]

    assert UniqueStateGroups.expand(:successful) == [
             :suspended,
             :available,
             :scheduled,
             :executing,
             :retryable,
             :completed
           ]
  end

  test "expands groups inside an explicit state list" do
    assert UniqueStateGroups.expand([:available, :scheduled]) == [:available, :scheduled]

    assert :discarded in UniqueStateGroups.expand([:available, :all])
    assert UniqueStateGroups.expand([:incomplete]) == UniqueStateGroups.expand(:incomplete)
  end

  test "referenced_groups finds a bare group and groups mixed into a list" do
    assert UniqueStateGroups.referenced_groups(:all) == [:all]
    assert UniqueStateGroups.referenced_groups([:available, :all]) == [:all]
    # :scheduled is both a concrete job state and a named group.
    assert UniqueStateGroups.referenced_groups([:available, :scheduled]) == [:scheduled]
    assert UniqueStateGroups.referenced_groups([:available, :executing]) == []
    assert UniqueStateGroups.referenced_groups(nil) == []
  end
end
