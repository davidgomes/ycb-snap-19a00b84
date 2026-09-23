defmodule PetalComponents.DataTableTest do
  use ComponentCase

  import PetalComponents.DataTable

  alias PetalComponents.DataTable
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

  @people [
    %{id: 1, name: "Amy", email: "amy@x.com"},
    %{id: 2, name: "Bea", email: "bea@x.com"}
  ]

  test "selectable: tri-state header, page ops, and the morphing toolbar" do
    assigns = base(%{rows: @people, state: %State{total: 2, page_size: 10}})

    mixed =
      rendered_to_string(~H"""
      <.data_table
        id="t"
        rows={@rows}
        state={@state}
        on_change="table"
        searchable
        selectable
        row_id={& &1.id}
        selected={[1]}
      >
        <:col :let={row} field={:name}>{row.name}</:col>
        <:bulk_action :let={ids}><span data-bulk={length(ids)}>Export</span></:bulk_action>
      </.data_table>
      """)

    assert mixed =~ ~s(data-pc-dt-select-all)
    assert mixed =~ ~s(data-state="mixed")
    assert mixed =~ ~s(data-id="1")
    assert mixed =~ ~s(phx-click="table")
    assert mixed =~ ~s(phx-value-op="select")
    assert mixed =~ ~s(phx-value-op="select_page")
    assert mixed =~ ~s(phx-value-on="true")
    assert mixed =~ ~s(phx-value-ids="[&quot;1&quot;,&quot;2&quot;]")
    assert mixed =~ "1 selected"
    assert mixed =~ ~s(data-bulk="1")
    assert mixed =~ ~s(phx-value-op="clear_selection")
    assert mixed =~ ~s(data-active="false")
    assert mixed =~ ~s(data-active="true")
    assert mixed =~ ~s(phx-hook="PetalDataTable")
    assert mixed =~ "pc-table__td--first-col"
    refute mixed =~ "pc-data-table__select-td pc-table__td--first-col"
    refute mixed =~ "pc-table__td--first-col pc-data-table__select-td"

    all =
      rendered_to_string(~H"""
      <.data_table
        id="t"
        rows={@rows}
        state={@state}
        on_change="table"
        selectable
        row_id={& &1.id}
        selected={[1, 2]}
      >
        <:col :let={row} field={:name}>{row.name}</:col>
      </.data_table>
      """)

    assert all =~ ~s(data-state="all")
    assert all =~ ~s(checked)
    assert all =~ ~s(phx-value-on="false")
    assert all =~ "2 selected"

    none =
      rendered_to_string(~H"""
      <.data_table
        id="t"
        rows={@rows}
        state={@state}
        path={@path}
        on_select="pick"
        selectable
        row_id={& &1.id}
        selected={[]}
        searchable
      >
        <:col :let={row} field={:name}>{row.name}</:col>
      </.data_table>
      """)

    assert none =~ ~s(data-state="none")
    assert none =~ ~s(phx-click="pick")
    assert none =~ "0 selected"
    refute none =~ ~s(checked)
  end

  test "selection outside the page still morphs the toolbar; the header stays empty" do
    assigns = base(%{rows: @people, myself: "myself"})

    html =
      rendered_to_string(~H"""
      <.data_table
        id="t"
        rows={@rows}
        state={@state}
        on_change="table"
        selectable
        row_id={& &1.id}
        selected={MapSet.new([99])}
        target={@myself}
      >
        <:col :let={row} field={:name}>{row.name}</:col>
      </.data_table>
      """)

    assert html =~ ~s(data-state="none")
    assert html =~ "1 selected"
    assert html =~ ~s(phx-target="myself")
    refute html =~ ~s(data-id="99")
  end

  test "loading disables the header checkbox and skips row ids" do
    assigns = base(%{rows: @people})

    html =
      rendered_to_string(~H"""
      <.data_table
        id="t"
        rows={@rows}
        state={@state}
        on_change="table"
        selectable
        row_id={& &1.id}
        loading
      >
        <:col :let={row} field={:name}>{row.name}</:col>
      </.data_table>
      """)

    assert html =~ ~s(disabled)
    assert html =~ "pc-data-table__skeleton--check"
    refute html =~ "data-id="
  end

  test "selectable requires row_id and an event" do
    assigns = base(%{rows: @people})

    assert_raise ArgumentError, ~r/row_id/, fn ->
      rendered_to_string(~H"""
      <.data_table id="t" rows={@rows} state={@state} on_change="table" selectable>
        <:col :let={row} field={:name}>{row.name}</:col>
      </.data_table>
      """)
    end

    assert_raise ArgumentError, ~r/on_select or on_change/, fn ->
      rendered_to_string(~H"""
      <.data_table id="t" rows={@rows} state={@state} path={@path} selectable row_id={& &1.id}>
        <:col :let={row} field={:name}>{row.name}</:col>
      </.data_table>
      """)
    end
  end

  test "selection_op toggles, unions a page, clears, and ignores other ops" do
    assert DataTable.selection_op([1], %{"op" => "select", "id" => "2", "on" => "true"}) ==
             ["1", "2"]

    assert DataTable.selection_op(["1", "2"], %{"op" => "select", "id" => "1", "on" => "false"}) ==
             ["2"]

    assert DataTable.selection_op(["1"], %{"op" => "select", "id" => "1"}) == []

    assert DataTable.selection_op(["9"], %{
             "op" => "select_page",
             "ids" => ~s(["1","2"]),
             "on" => "true"
           }) == ["9", "1", "2"]

    assert DataTable.selection_op(["1", "2", "3"], %{
             "op" => "select_page",
             "ids" => "2,3",
             "on" => "false"
           }) == ["1"]

    assert DataTable.selection_op(["1"], %{"op" => "clear_selection"}) == []

    selected = [1]
    assert DataTable.selection_op(selected, %{"op" => "sort", "field" => "name"}) == selected

    assert DataTable.selection_op(MapSet.new(["a"]), %{"op" => "select", "id" => "b", "on" => "true"})
           |> Enum.sort() == ["a", "b"]
  end

  test "a custom selection label replaces the count sentence" do
    assigns = base(%{rows: @people})

    html =
      rendered_to_string(~H"""
      <.data_table
        id="t"
        rows={@rows}
        state={@state}
        on_change="table"
        selectable
        row_id={& &1.id}
        selected={[1, 2]}
        selection_label={fn n -> "#{n} picked" end}
      >
        <:col :let={row} field={:name}>{row.name}</:col>
      </.data_table>
      """)

    assert html =~ "2 picked"
    refute html =~ "2 selected"
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
