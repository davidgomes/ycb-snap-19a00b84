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

  describe "selectable" do
    @keyed [
      %{id: 1, name: "Amy"},
      %{id: 2, name: "Bea"},
      %{id: 3, name: "Cal"}
    ]

    defp selectable(state, extra \\ %{}) do
      assigns = Map.merge(%{rows: @keyed, state: state, loading: false}, extra)

      rendered_to_string(~H"""
      <.data_table id="t" rows={@rows} state={@state} on_change="table" loading={@loading} selectable>
        <:col :let={row} field={:name}>{row.name}</:col>
        <:bulk_action :let={selected}>
          <button type="button" phx-click="archive">Archive {inspect(selected)}</button>
        </:bulk_action>
      </.data_table>
      """)
      |> LazyHTML.from_fragment()
    end

    defp push_value(doc, selector) do
      [js] = doc |> LazyHTML.query(selector) |> LazyHTML.attribute("phx-click")
      [["push", %{"event" => event, "value" => value}]] = Jason.decode!(js)
      {event, value}
    end

    defp checked_count(doc, selector),
      do: doc |> LazyHTML.query(selector <> "[checked]") |> Enum.count()

    test "a leading checkbox column keyed by :id, pushing the op grammar" do
      doc = selectable(%State{total: 3, selected: ["2"]})

      assert doc |> LazyHTML.query(".pc-data-table__row-select") |> Enum.count() == 3
      assert checked_count(doc, ".pc-data-table__row-select") == 1

      assert push_value(doc, "tr:nth-child(2) .pc-data-table__row-select") ==
               {"table", %{"op" => "select", "id" => "1"}}

      assert push_value(doc, "[data-pc-dt-select-page]") ==
               {"table", %{"op" => "select_page", "ids" => ["1", "2", "3"]}}

      # the checkbox cell is the table's first column; the empty row spans it
      assert doc |> LazyHTML.query("th.pc-data-table__select-th") |> Enum.count() == 1
      assert doc |> LazyHTML.query("td[colspan=\"2\"]") |> Enum.count() == 1
    end

    test "the header is tri-state for the page, stamped for the hook" do
      root = fn doc ->
        doc |> LazyHTML.query("#t") |> LazyHTML.attribute("data-page-selection")
      end

      none = selectable(%State{total: 3})
      assert root.(none) == ["none"]
      assert checked_count(none, "[data-pc-dt-select-page]") == 0

      some = selectable(%State{total: 3, selected: ["1"]})
      assert root.(some) == ["some"]
      assert checked_count(some, "[data-pc-dt-select-page]") == 0

      all = selectable(%State{total: 3, selected: ["3", "1", "2"]})
      assert root.(all) == ["all"]
      assert checked_count(all, "[data-pc-dt-select-page]") == 1

      assert none |> LazyHTML.query("#t[phx-hook=PetalDataTable]") |> Enum.count() == 1
    end

    test "a selection on another page leaves this page's header unchecked but counts" do
      doc = selectable(%State{total: 30, selected: ["41", "42"]})

      assert doc |> LazyHTML.query("#t") |> LazyHTML.attribute("data-page-selection") == ["none"]
      assert LazyHTML.text(LazyHTML.query(doc, ".pc-data-table__selection-count")) =~ "2 selected"
    end

    test "the toolbar morphs while rows are selected, keeping the controls in the DOM" do
      idle = selectable(%State{total: 3})
      assert idle |> LazyHTML.query(".pc-data-table__toolbar--selecting") |> Enum.count() == 0
      # both faces always render - they share one grid cell, so the height holds
      assert idle |> LazyHTML.query(".pc-data-table__selection-bar") |> Enum.count() == 1

      doc = selectable(%State{total: 3, selected: ["1", "3"]})
      assert doc |> LazyHTML.query(".pc-data-table__toolbar--selecting") |> Enum.count() == 1
      assert doc |> LazyHTML.query(".pc-data-table__toolbar-main") |> Enum.count() == 1

      bar = LazyHTML.query(doc, ".pc-data-table__selection-bar")
      assert LazyHTML.text(bar) =~ "2 selected"
      # :bulk_action's :let receives the selection
      assert LazyHTML.text(bar) =~ ~s(Archive ["1", "3"])

      assert bar
             |> LazyHTML.query(".pc-data-table__clear-selection")
             |> LazyHTML.attribute("phx-value-op") == ["clear_selection"]
    end

    test "a fully picked page offers select-all-matching; under :all the count is the total" do
      paged = selectable(%State{total: 74, selected: ["1", "2", "3"]})
      offer = LazyHTML.query(paged, ".pc-data-table__select-all")

      assert LazyHTML.text(offer) =~ "Select all 74"
      assert LazyHTML.attribute(offer, "phx-value-op") == ["select_all"]

      # a partial page, or a page that IS every match, has nothing more to offer
      partial = selectable(%State{total: 74, selected: ["1"]})
      assert partial |> LazyHTML.query(".pc-data-table__select-all") |> Enum.count() == 0
      whole = selectable(%State{total: 3, selected: ["1", "2", "3"]})
      assert whole |> LazyHTML.query(".pc-data-table__select-all") |> Enum.count() == 0

      all = selectable(%State{total: 74, selected: :all})
      assert all |> LazyHTML.query(".pc-data-table__select-all") |> Enum.count() == 0

      assert LazyHTML.text(LazyHTML.query(all, ".pc-data-table__selection-count")) =~
               "74 selected"

      assert checked_count(all, ".pc-data-table__row-select") == 3

      # unchecking a row narrows :all to the page, so rows carry the page ids
      assert push_value(all, "tr:nth-child(3) .pc-data-table__row-select") ==
               {"table", %{"op" => "select", "id" => "2", "ids" => ["1", "2", "3"]}}
    end

    test "loading disables the header and renders no row checkboxes" do
      doc = selectable(%State{total: 74, page_size: 3}, %{loading: true})

      assert doc |> LazyHTML.query(".pc-data-table__row-select") |> Enum.count() == 0
      assert doc |> LazyHTML.query("[data-pc-dt-select-page][disabled]") |> Enum.count() == 1
    end

    test "row_key keys rows by any function" do
      assigns = %{
        rows: [%{sku: "A-1"}, %{sku: "B-2"}],
        state: %State{total: 2, selected: ["B-2"]}
      }

      html =
        rendered_to_string(~H"""
        <.data_table
          id="t"
          rows={@rows}
          state={@state}
          on_change="table"
          selectable
          row_key={& &1.sku}
        >
          <:col :let={row} field={:sku}>{row.sku}</:col>
        </.data_table>
        """)

      doc = LazyHTML.from_fragment(html)
      assert checked_count(doc, ".pc-data-table__row-select") == 1

      assert push_value(doc, "[data-pc-dt-select-page]") ==
               {"table", %{"op" => "select_page", "ids" => ["A-1", "B-2"]}}
    end

    test "link mode pushes selection through on_select; patch URLs never carry it" do
      assigns = %{rows: @keyed, state: %State{total: 74, selected: ["1"], order_by: [name: :asc]}}

      html =
        rendered_to_string(~H"""
        <.data_table id="t" rows={@rows} state={@state} path="/orders" on_select="select" selectable>
          <:col :let={row} field={:name} sortable>{row.name}</:col>
        </.data_table>
        """)

      doc = LazyHTML.from_fragment(html)

      assert push_value(doc, "tr:nth-child(2) .pc-data-table__row-select") ==
               {"select", %{"op" => "select", "id" => "1"}}

      assert doc
             |> LazyHTML.query(".pc-data-table__clear-selection")
             |> LazyHTML.attribute("phx-click") == ["select"]

      assert html =~ "order_by=name%3Adesc"
      refute html =~ "selected="
    end

    test "raises when selectable has no event to push" do
      assigns = %{rows: @keyed, state: %State{total: 3}}

      assert_raise ArgumentError, ~r/on_select/, fn ->
        rendered_to_string(~H"""
        <.data_table id="t" rows={@rows} state={@state} path="/orders" selectable>
          <:col :let={row} field={:name}>{row.name}</:col>
        </.data_table>
        """)
      end
    end

    test "a plain table renders no selection chrome" do
      assigns = base()

      html =
        rendered_to_string(~H"""
        <.data_table id="t" rows={@rows} state={@state} path={@path}>
          <:col :let={row} field={:name}>{row.name}</:col>
        </.data_table>
        """)

      refute html =~ "pc-data-table__toolbar"
      refute html =~ "pc-data-table__row-select"
      refute html =~ "data-page-selection"
      refute html =~ "PetalDataTable"
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
