defmodule PetalComponents.DataTableTest do
  use ComponentCase

  import PetalComponents.DataTable

  alias PetalComponents.DataTable.State

  @rows [
    %{name: "Amy", email: "amy@x.com", amount: 300},
    %{name: "Bea", email: "bea@x.com", amount: 40}
  ]

  defp base(assigns \\ %{}) do
    Map.merge(%{rows: @rows, state: %State{total: 74}, path: "/orders"}, assigns)
  end

  test "searchable event mode: a phx-change form posts the search op with debounce" do
    assigns = base(%{state: %State{total: 74, search: "amy"}})

    html =
      rendered_to_string(~H"""
      <.data_table id="t" rows={@rows} state={@state} on_change="table" searchable>
        <:col :let={row} field={:name}>{row.name}</:col>
      </.data_table>
      """)

    assert html =~ ~s(phx-change="table")
    assert html =~ ~s(name="op" value="search")
    assert html =~ ~s(phx-debounce="300")
    assert html =~ ~s(value="amy")
    refute html =~ "PetalDataTable"
  end

  test "searchable link mode: the hook mounts with a :term URL template and a nav anchor" do
    assigns = base(%{state: %State{total: 74, order_by: [name: :desc]}})

    html =
      rendered_to_string(~H"""
      <.data_table id="t" rows={@rows} state={@state} path={@path} searchable>
        <:col :let={row} field={:name}>{row.name}</:col>
      </.data_table>
      """)

    assert html =~ ~s(phx-hook="PetalDataTable")
    assert html =~ "data-pc-dt-search"
    assert html =~ "data-pc-dt-nav"
    assert html =~ ~s(data-nav-template="/orders?search=:term&amp;order_by=name%3Adesc")
  end

  test "page_size_options renders the footer select in both wiring modes" do
    assigns = base(%{state: %State{total: 74, page_size: 20}})

    event_html =
      rendered_to_string(~H"""
      <.data_table id="t" rows={@rows} state={@state} on_change="table" page_size_options={[10, 20, 50]}>
        <:col :let={row} field={:name}>{row.name}</:col>
      </.data_table>
      """)

    assert event_html =~ ~s(name="op" value="page_size")
    assert event_html =~ ~s(<option value="20" selected>)

    link_html =
      rendered_to_string(~H"""
      <.data_table id="t" rows={@rows} state={@state} path={@path} page_size_options={[10, 20, 50]}>
        <:col :let={row} field={:name}>{row.name}</:col>
      </.data_table>
      """)

    assert link_html =~ "data-pc-dt-page-size"
    assert link_html =~ ~s(data-nav-template="/orders?page_size=:page_size")
  end

  test "filterable columns render popover editors typed per column" do
    assigns =
      base(%{
        rows: [
          %{name: "Amy", email: "amy@x.com", amount: 300, status: "pending"},
          %{name: "Bea", email: "bea@x.com", amount: 40, status: "paid"}
        ],
        state: %State{
          total: 74,
          filters: [%{field: :status, op: :in, value: ["pending", "paid"]}]
        }
      })

    html =
      rendered_to_string(~H"""
      <.data_table id="t" rows={@rows} state={@state} on_change="table">
        <:col :let={row} field={:email} filterable="text">{row.email}</:col>
        <:col :let={row} field={:amount} filterable="number">{row.amount}</:col>
        <:col :let={row} field={:status} filterable="select" options={["pending", "paid", "refunded"]}>
          {row.status}
        </:col>
      </.data_table>
      """)

    # text editor: op select with the text grammar
    assert html =~ ~s(name="filter_op")
    assert html =~ ~s(value="starts_with")
    # number editor: between + second bound input
    assert html =~ ~s(value="between")
    assert html =~ ~s(name="value2")
    # select editor: checkboxes, current picks checked
    assert html =~ ~s(name="values[]")
    assert html =~ ~s(value="pending" checked)
    refute html =~ ~s(value="refunded" checked)
    # active trigger reads the predicate; its clear button posts removal
    assert html =~ "Status is any of Pending, Paid"
    assert html =~ ~s(aria-label="Clear Status filter")
    # event mode carries the op grammar in hidden inputs; the hook mounts
    # only to close top-layer popovers - no URL wiring
    assert html =~ ~s(name="op" value="filter")
    assert html =~ ~s(phx-hook="PetalDataTable")
    assert html =~ ~s(popover="auto")
    refute html =~ "data-nav-template"
    refute html =~ "data-filters="
  end

  test "filterable link mode: hook + :filters placeholder + JSON stamp + clear URL" do
    assigns =
      base(%{
        state: %State{total: 74, filters: [%{field: :email, op: :contains, value: "d"}]}
      })

    html =
      rendered_to_string(~H"""
      <.data_table id="t" rows={@rows} state={@state} path={@path}>
        <:col :let={row} field={:email} filterable="text">{row.email}</:col>
      </.data_table>
      """)

    assert html =~ ~s(phx-hook="PetalDataTable")
    assert html =~ "data-pc-dt-filter"
    assert html =~ ~s(data-field="email")
    assert html =~ ~s(data-nav-template="/orders?:filters")
    assert html =~ ~s(data-filters=)
    assert html =~ "contains"
    # the clear affordance patches to a filterless URL
    assert html =~ ~s(aria-label="Clear Email filter")
    refute html =~ ~s(href="/orders?filters)
  end

  test "a map-shaped between range renders instead of crashing" do
    assigns =
      base(%{
        state: %State{
          total: 74,
          filters: [%{field: :amount, op: :between, value: %{"min" => "10", "max" => "90"}}]
        }
      })

    html =
      rendered_to_string(~H"""
      <.data_table id="t" rows={@rows} state={@state} on_change="table">
        <:col :let={row} field={:amount} filterable="number">{row.amount}</:col>
      </.data_table>
      """)

    assert html =~ "Amount between 10–90"
    assert html =~ ~s(name="value" value="10")
    assert html =~ ~s(name="value2" value="90")
  end

  test "reset filters button appears only while filters are active" do
    filtered = %State{total: 74, filters: [%{field: :name, op: :contains, value: "a"}]}
    assigns = base(%{filtered: filtered})

    clean_html =
      rendered_to_string(~H"""
      <.data_table id="t" rows={@rows} state={@state} path={@path}>
        <:col :let={row} field={:name}>{row.name}</:col>
      </.data_table>
      """)

    refute clean_html =~ "Reset filters"

    link_html =
      rendered_to_string(~H"""
      <.data_table id="t" rows={@rows} state={@filtered} path={@path}>
        <:col :let={row} field={:name}>{row.name}</:col>
      </.data_table>
      """)

    assert link_html =~ "Reset filters"
    assert link_html =~ ~s(href="/orders")

    event_html =
      rendered_to_string(~H"""
      <.data_table id="t" rows={@rows} state={@filtered} on_change="table">
        <:col :let={row} field={:name}>{row.name}</:col>
      </.data_table>
      """)

    assert event_html =~ "Reset filters"
    assert event_html =~ ~s(phx-value-op="clear_filters")
  end

  test "renders rows through col slots with explicit and humanized labels" do
    assigns = base()

    html =
      rendered_to_string(~H"""
      <.data_table id="t" rows={@rows} state={@state} path={@path}>
        <:col :let={row} field={:name} label="Person">{row.name}</:col>
        <:col :let={row} field={:email}>{row.email}</:col>
      </.data_table>
      """)

    assert html =~ "Person"
    assert html =~ "Email"
    assert html =~ "amy@x.com"
    assert html =~ "Bea"
  end

  test "link mode: sortable headers patch toggled sort URLs; current sort carries aria-sort" do
    assigns = base(%{state: %State{total: 74, order_by: [name: :asc]}})

    html =
      rendered_to_string(~H"""
      <.data_table id="t" rows={@rows} state={@state} path={@path}>
        <:col :let={row} field={:name} sortable>{row.name}</:col>
      </.data_table>
      """)

    # toggling an asc sort patches to desc
    assert html =~ "order_by=name%3Adesc" or html =~ "order_by=name:desc"
    assert html =~ ~s|aria-sort="ascending"|
  end

  test "event mode: sort pushes the op grammar through on_change" do
    assigns = base(%{path: nil})

    html =
      rendered_to_string(~H"""
      <.data_table id="t" rows={@rows} state={@state} on_change="table">
        <:col :let={row} field={:name} sortable>{row.name}</:col>
      </.data_table>
      """)

    assert html =~ "phx-click"
    assert html =~ "table"
    assert html =~ "sort"
    assert html =~ "name"
  end

  test "footer range and numbered pagination when total is known" do
    assigns = base(%{state: %State{total: 74, page: 2}})

    html =
      rendered_to_string(~H"""
      <.data_table id="t" rows={@rows} state={@state} path={@path}>
        <:col :let={row} field={:name}>{row.name}</:col>
      </.data_table>
      """)

    assert html =~ "11–20 of 74"
    assert html =~ "pc-pagination__inner"
    # the page template keeps the rest of the query
    assert html =~ "page=:page" or html =~ "/orders?page="
  end

  test "cursor mode (nil total) renders the page word and the simple pagination" do
    assigns = base(%{state: %State{total: nil, page: 3}})

    html =
      rendered_to_string(~H"""
      <.data_table id="t" rows={@rows} state={@state} path={@path}>
        <:col :let={row} field={:name}>{row.name}</:col>
      </.data_table>
      """)

    assert html =~ "Page 3"
    assert html =~ "pc-pagination__simple"
  end

  test "loading renders skeleton rows instead of data" do
    assigns = base(%{state: %State{total: 74, page_size: 3}})

    html =
      rendered_to_string(~H"""
      <.data_table id="t" rows={@rows} state={@state} path={@path} loading>
        <:col :let={row} field={:name}>{row.name}</:col>
      </.data_table>
      """)

    refute html =~ "Amy"
    assert length(String.split(html, "pc-data-table__skeleton")) - 1 >= 3
  end

  test "empty default is filters-aware: plain text bare, clear affordance when filtered" do
    assigns = base(%{rows: [], state: %State{total: 0}})

    plain =
      rendered_to_string(~H"""
      <.data_table id="t" rows={@rows} state={@state} path={@path}>
        <:col :let={row} field={:name}>{row.name}</:col>
      </.data_table>
      """)

    assert plain =~ "No results"
    refute plain =~ "Clear filters"

    assigns =
      base(%{
        rows: [],
        state: %State{total: 0, filters: [%{field: :name, op: :contains, value: "zz"}]}
      })

    filtered =
      rendered_to_string(~H"""
      <.data_table id="t" rows={@rows} state={@state} path={@path}>
        <:col :let={row} field={:name}>{row.name}</:col>
      </.data_table>
      """)

    assert filtered =~ "No results for these filters"
    assert filtered =~ "Clear filters"
    # the clear link drops the filters from the query
    refute filtered =~ ~s|href="/orders?filters|
  end

  test "filters flatten into indexed query params the State can read back" do
    state = %State{total: 74, filters: [%{field: :name, op: :contains, value: "am"}]}
    assigns = base(%{state: state})

    html =
      rendered_to_string(~H"""
      <.data_table id="t" rows={@rows} state={@state} path={@path}>
        <:col :let={row} field={:name} sortable>{row.name}</:col>
      </.data_table>
      """)

    assert html =~ "filters%5B0%5D%5Bfield%5D=name" or html =~ "filters[0][field]=name"
  end

  test "a base path already carrying a query joins with & not ?" do
    assigns = base(%{path: "/orders?tab=all"})

    html =
      rendered_to_string(~H"""
      <.data_table id="t" rows={@rows} state={@state} path={@path}>
        <:col :let={row} field={:name} sortable>{row.name}</:col>
      </.data_table>
      """)

    assert html =~ "/orders?tab=all&amp;" or html =~ "/orders?tab=all&"
    refute html =~ "tab=all?"
  end

  test "action slot renders a trailing column" do
    assigns = base()

    html =
      rendered_to_string(~H"""
      <.data_table id="t" rows={@rows} state={@state} path={@path}>
        <:col :let={row} field={:name}>{row.name}</:col>
        <:action :let={row}><button type="button">Edit {row.name}</button></:action>
      </.data_table>
      """)

    assert html =~ "Edit Amy"
    assert html =~ "pc-data-table__actions"
  end

  describe "row selection" do
    @people [
      %{id: 1, name: "Amy"},
      %{id: 2, name: "Bea"},
      %{id: 3, name: "Cal"}
    ]

    # JS.push commands render as HTML-escaped JSON; decode them back
    defp pushes(html) do
      ~r/phx-click="(\[\[&quot;push&quot;[^"]*)"/
      |> Regex.scan(html, capture: :all_but_first)
      |> Enum.map(fn [attr] ->
        [["push", args]] =
          attr
          |> String.replace("&quot;", "\"")
          |> String.replace("&amp;", "&")
          |> Jason.decode!()

        args
      end)
    end

    defp push_values(html, op) do
      html |> pushes() |> Enum.map(& &1["value"]) |> Enum.filter(&(&1["op"] == op))
    end

    test "a leading checkbox column: rows push select, the header pushes select_all for the page" do
      assigns = base(%{rows: @people})

      html =
        rendered_to_string(~H"""
        <.data_table id="t" rows={@rows} state={@state} on_change="table" selectable>
          <:col :let={row} field={:name}>{row.name}</:col>
        </.data_table>
        """)

      assert html =~ ~s(phx-hook="PetalDataTable")
      assert count_substring(html, "data-pc-dt-select ") == 3
      assert html =~ ~s(aria-label="Select all rows on this page")

      assert push_values(html, "select") == [
               %{"op" => "select", "id" => "1"},
               %{"op" => "select", "id" => "2"},
               %{"op" => "select", "id" => "3"}
             ]

      assert push_values(html, "select_all") == [
               %{"op" => "select_all", "ids" => ["1", "2", "3"], "selected" => true}
             ]

      assert html |> pushes() |> Enum.all?(&(&1["event"] == "table"))
      # nothing selected: no morph, no tri-state stamp
      refute html =~ "pc-data-table__toolbar--selection"
      refute html =~ "data-pc-dt-indeterminate"
    end

    test "the header is tri-state: some picked stamps indeterminate, all picked checks it" do
      assigns = base(%{rows: @people, some: [2], all: [1, 2, 3]})

      some_html =
        rendered_to_string(~H"""
        <.data_table id="t" rows={@rows} state={@state} on_change="table" selectable selected={@some}>
          <:col :let={row} field={:name}>{row.name}</:col>
        </.data_table>
        """)

      assert some_html =~ "data-pc-dt-indeterminate"
      refute some_html =~ ~r/data-pc-dt-select-all[^>]*checked/
      assert count_substring(some_html, "data-pc-dt-select checked") == 1
      assert [%{"selected" => true}] = push_values(some_html, "select_all")

      all_html =
        rendered_to_string(~H"""
        <.data_table id="t" rows={@rows} state={@state} on_change="table" selectable selected={@all}>
          <:col :let={row} field={:name}>{row.name}</:col>
        </.data_table>
        """)

      refute all_html =~ "data-pc-dt-indeterminate"
      assert all_html =~ ~r/data-pc-dt-select-all[^>]*checked/
      # a full page unchecks as a unit
      assert [%{"selected" => false}] = push_values(all_html, "select_all")
    end

    test "while rows are selected the toolbar morphs into count + bulk actions + clear" do
      assigns = base(%{rows: @people, selected: [1, 3]})

      html =
        rendered_to_string(~H"""
        <.data_table
          id="t"
          rows={@rows}
          state={@state}
          on_change="table"
          selectable
          searchable
          selected={@selected}
        >
          <:col :let={row} field={:name}>{row.name}</:col>
          <:bulk_action :let={ids}>
            <button type="button">Archive {Enum.join(ids, "+")}</button>
          </:bulk_action>
        </.data_table>
        """)

      assert html =~ "pc-data-table__toolbar--selection"
      assert html =~ ~r/2\s+selected/
      assert html =~ "Archive 1+3"
      assert html =~ "Clear selection"
      assert html =~ ~s(phx-value-op="clear_selection")
      # the normal toolbar stays mounted, just hidden
      assert html =~ ~r/class="pc-data-table__toolbar" hidden/
      assert html =~ "pc-data-table__search-input"
    end

    test "one normalized selection: stringified, blank-free, deduped for count, slot and checks" do
      assigns = base(%{rows: @people, selected: [1, "1", nil, "", "  ", 2]})

      html =
        rendered_to_string(~H"""
        <.data_table id="t" rows={@rows} state={@state} on_change="table" selectable selected={@selected}>
          <:col :let={row} field={:name}>{row.name}</:col>
          <:bulk_action :let={ids}>
            <span>ids:{inspect(ids)}</span>
          </:bulk_action>
        </.data_table>
        """)

      assert html =~ ~r/2\s+selected/
      assert html =~ "ids:[&quot;1&quot;, &quot;2&quot;]"
      assert count_substring(html, "data-pc-dt-select checked") == 2
    end

    test "link mode: selection rides on_ui, never the URL, and is required" do
      assigns = base(%{rows: @people, state: %State{total: 74, order_by: [name: :asc]}})

      html =
        rendered_to_string(~H"""
        <.data_table id="t" rows={@rows} state={@state} path={@path} on_ui="ui" selectable selected={[1]}>
          <:col :let={row} field={:name} sortable>{row.name}</:col>
        </.data_table>
        """)

      assert [%{"event" => "ui"} | _] = pushes(html)
      assert html =~ ~s(phx-click="ui")
      refute html =~ ~r/href="[^"]*select/

      assert_raise ArgumentError, ~r/on_ui/, fn ->
        rendered_to_string(~H"""
        <.data_table id="t" rows={@rows} state={@state} path={@path} selectable>
          <:col :let={row} field={:name}>{row.name}</:col>
        </.data_table>
        """)
      end
    end

    test "on_ui overrides on_change in event mode too, and carries the target" do
      assigns = base(%{rows: @people})

      html =
        rendered_to_string(~H"""
        <.data_table
          id="t"
          rows={@rows}
          state={@state}
          on_change="table"
          on_ui="ui"
          target="#c"
          selectable
        >
          <:col :let={row} field={:name}>{row.name}</:col>
        </.data_table>
        """)

      selection_pushes = Enum.filter(pushes(html), &(&1["value"]["op"] in ~w(select select_all)))
      assert selection_pushes != []
      assert Enum.all?(selection_pushes, &(&1["event"] == "ui" and &1["target"] == "#c"))
    end

    test "row_id takes a function; keyless rows render inert and stay out of select-all" do
      assigns =
        base(%{
          rows: [%{uuid: "a", name: "Amy"}, %{uuid: nil, name: "Bea"}, %{uuid: "c", name: "Cal"}]
        })

      html =
        rendered_to_string(~H"""
        <.data_table id="t" rows={@rows} state={@state} on_change="table" selectable row_id={& &1.uuid}>
          <:col :let={row} field={:name}>{row.name}</:col>
        </.data_table>
        """)

      assert count_substring(html, "data-pc-dt-select ") == 2
      assert html =~ ~r/<input type="checkbox" class="pc-checkbox pc-data-table__select" disabled/
      assert [%{"ids" => ["a", "c"]}] = push_values(html, "select_all")
    end

    test "a row_id repeated on one page raises" do
      assigns = base(%{rows: [%{id: 1, name: "Amy"}, %{id: 1, name: "Bea"}]})

      assert_raise ArgumentError, ~r/row_id "1" appears more than once/, fn ->
        rendered_to_string(~H"""
        <.data_table id="t" rows={@rows} state={@state} on_change="table" selectable>
          <:col :let={row} field={:name}>{row.name}</:col>
        </.data_table>
        """)
      end
    end

    test "loading: no row checkboxes and the header select-all is disabled" do
      assigns = base(%{state: %State{total: 74, page_size: 3}})

      html =
        rendered_to_string(~H"""
        <.data_table id="t" rows={[]} state={@state} on_change="table" selectable loading>
          <:col :let={row} field={:name}>{row}</:col>
        </.data_table>
        """)

      refute html =~ "data-pc-dt-select "
      assert html =~ ~r/data-pc-dt-select-all[^>]*disabled/
    end
  end

  test "raises without either wiring mode" do
    assigns = base(%{path: nil})

    assert_raise ArgumentError, ~r/path.*on_change/, fn ->
      rendered_to_string(~H"""
      <.data_table id="t" rows={@rows} state={@state}>
        <:col :let={row} field={:name}>{row.name}</:col>
      </.data_table>
      """)
    end
  end
end
