defmodule PetalComponents.DataTableTest do
  use ComponentCase

  import PetalComponents.DataTable

  alias PetalComponents.DataTable.State

  @rows [
    %{name: "Amy", email: "amy@x.com", amount: 300},
    %{name: "Bea", email: "bea@x.com", amount: 40}
  ]

  @id_rows [
    %{id: 1, name: "Amy"},
    %{id: 2, name: "Bea"}
  ]

  defp base(assigns \\ %{}) do
    Map.merge(%{rows: @rows, state: %State{total: 74}, path: "/orders"}, assigns)
  end

  defp query(html, selector), do: html |> parse_html() |> LazyHTML.query(selector)

  defp attrs(html, selector, name), do: html |> query(selector) |> LazyHTML.attribute(name)

  # JS.push commands render as JSON - decode each to its event + value
  defp pushes(html, selector) do
    html
    |> attrs(selector, "phx-click")
    |> Enum.map(fn js ->
      [["push", push]] = Jason.decode!(js)
      Map.take(push, ["event", "value"])
    end)
  end

  defp select_page_box(html), do: query(html, "th input[data-pc-dt-select-page]")

  describe "selectable" do
    test "the header checkbox is tri-state for the visible page" do
      assigns = base(%{rows: @id_rows})

      render = fn selected ->
        assigns = Map.put(assigns, :state, %State{total: 2, selected: MapSet.new(selected)})

        rendered_to_string(~H"""
        <.data_table id="t" rows={@rows} state={@state} on_change="table" selectable>
          <:col :let={row} field={:name}>{row.name}</:col>
        </.data_table>
        """)
      end

      none = render.([]) |> select_page_box()
      assert LazyHTML.attribute(none, "checked") == []
      assert LazyHTML.attribute(none, "data-indeterminate") == []

      # a pick on another page doesn't reach this page's header
      assert render.([99]) |> select_page_box() |> LazyHTML.attribute("data-indeterminate") == []

      some = render.([2]) |> select_page_box()
      assert LazyHTML.attribute(some, "checked") == []
      assert [_] = LazyHTML.attribute(some, "data-indeterminate")

      all = render.([1, 2]) |> select_page_box()
      assert [_] = LazyHTML.attribute(all, "checked")
      assert LazyHTML.attribute(all, "data-indeterminate") == []
    end

    test "row checkboxes reflect the selection and push typed ids through on_change" do
      assigns = base(%{rows: @id_rows, state: %State{total: 2, selected: MapSet.new([1])}})

      html =
        rendered_to_string(~H"""
        <.data_table id="t" rows={@rows} state={@state} on_change="table" selectable>
          <:col :let={row} field={:name}>{row.name}</:col>
        </.data_table>
        """)

      assert html =~ ~s(phx-hook="PetalDataTable")
      refute html =~ "data-nav-template"

      boxes = query(html, "td input.pc-data-table__select-row")
      assert Enum.count(boxes) == 2
      assert html |> query("td input.pc-data-table__select-row[checked]") |> Enum.count() == 1

      assert pushes(html, "td input.pc-data-table__select-row") == [
               %{"event" => "table", "value" => %{"op" => "select", "id" => 1}},
               %{"event" => "table", "value" => %{"op" => "select", "id" => 2}}
             ]

      assert pushes(html, "th input[data-pc-dt-select-page]") == [
               %{"event" => "table", "value" => %{"op" => "select_page", "ids" => [1, 2]}}
             ]
    end

    test "the toolbar morphs into the selection bar while rows are selected" do
      assigns = base(%{rows: @id_rows, state: %State{total: 2}})

      resting =
        rendered_to_string(~H"""
        <.data_table id="t" rows={@rows} state={@state} on_change="table" selectable searchable>
          <:col :let={row} field={:name}>{row.name}</:col>
          <:bulk_action :let={ids}><button type="button">Delete {length(ids)}</button></:bulk_action>
        </.data_table>
        """)

      assert attrs(resting, ".pc-data-table__toolbar--selectable", "hidden") == []
      refute resting =~ "pc-data-table__selection"
      refute resting =~ "Delete"

      assigns = base(%{rows: @id_rows, state: %State{total: 2, selected: MapSet.new([1, 2])}})

      selecting =
        rendered_to_string(~H"""
        <.data_table id="t" rows={@rows} state={@state} on_change="table" selectable searchable>
          <:col :let={row} field={:name}>{row.name}</:col>
          <:bulk_action :let={ids}><button type="button">Delete {length(ids)}</button></:bulk_action>
        </.data_table>
        """)

      # the controls stay in the DOM, hidden - the search term survives the morph
      assert [_] = attrs(selecting, ".pc-data-table__toolbar--selectable", "hidden")
      assert selecting =~ ~s(name="term")

      bar = query(selecting, ".pc-data-table__selection")
      assert LazyHTML.text(query(bar, ".pc-data-table__selection-count")) == "2 selected"
      assert LazyHTML.text(query(bar, ".pc-data-table__bulk-actions")) =~ "Delete 2"

      assert attrs(bar, ".pc-data-table__selection-clear", "phx-value-op") == ["clear_selection"]
      assert attrs(bar, ".pc-data-table__selection-clear", "phx-click") == ["table"]

      # the count is announced through a live region that outlives the bar
      assert LazyHTML.text(query(selecting, "span.sr-only[aria-live=polite]")) == "2 selected"
      assert [_] = resting |> query("span.sr-only[aria-live=polite]") |> Enum.to_list()
    end

    test "a selectable table always renders its toolbar, even with nothing else in it" do
      assigns = base(%{rows: @id_rows})

      html =
        rendered_to_string(~H"""
        <.data_table id="t" rows={@rows} state={@state} on_change="table" selectable>
          <:col :let={row} field={:name}>{row.name}</:col>
        </.data_table>
        """)

      assert html =~ "pc-data-table__toolbar--selectable"
    end

    test "link mode needs on_select and pushes selection through it" do
      assigns = base(%{rows: @id_rows})

      assert_raise ArgumentError, ~r/on_select/, fn ->
        rendered_to_string(~H"""
        <.data_table id="t" rows={@rows} state={@state} path={@path} selectable>
          <:col :let={row} field={:name}>{row.name}</:col>
        </.data_table>
        """)
      end

      assigns = base(%{rows: @id_rows, state: %State{total: 2, selected: MapSet.new([2])}})

      html =
        rendered_to_string(~H"""
        <.data_table id="t" rows={@rows} state={@state} path={@path} on_select="select" selectable>
          <:col :let={row} field={:name} sortable>{row.name}</:col>
        </.data_table>
        """)

      assert html =~ ~s(phx-hook="PetalDataTable")
      # sorting still patches URLs; selection alone needs no nav template
      assert html =~ "order_by=name"
      refute html =~ "data-nav-template"

      assert [%{"event" => "select"}, %{"event" => "select"}] =
               pushes(html, "td input.pc-data-table__select-row")

      assert attrs(html, ".pc-data-table__selection-clear", "phx-click") == ["select"]
    end

    test "row_id keys the selection by a custom id and targets components" do
      assigns =
        base(%{
          rows: [%{uuid: "a-1", name: "Amy"}],
          state: %State{total: 1, selected: MapSet.new(["a-1"])}
        })

      html =
        rendered_to_string(~H"""
        <.data_table
          id="t"
          rows={@rows}
          state={@state}
          on_change="table"
          target="#orders"
          row_id={& &1.uuid}
          selectable
        >
          <:col :let={row} field={:name}>{row.name}</:col>
        </.data_table>
        """)

      assert [_] = attrs(html, "th input[data-pc-dt-select-page]", "checked")

      [[["push", push]]] =
        html
        |> attrs("td input.pc-data-table__select-row", "phx-click")
        |> Enum.map(&Jason.decode!/1)

      assert push["value"] == %{"op" => "select", "id" => "a-1"}
      assert push["target"] == "#orders"
    end

    test "loading renders no row checkboxes and disables the header" do
      assigns = base(%{rows: @id_rows})

      html =
        rendered_to_string(~H"""
        <.data_table id="t" rows={@rows} state={@state} on_change="table" selectable loading>
          <:col :let={row} field={:name}>{row.name}</:col>
        </.data_table>
        """)

      refute html =~ "pc-data-table__select-row"
      assert [_] = attrs(html, "th input[data-pc-dt-select-page]", "disabled")
      assert attrs(html, "th input[data-pc-dt-select-page]", "phx-click") == []
    end

    test "an empty page disables the header and the empty row spans the checkbox column" do
      assigns = base(%{rows: [], state: %State{total: 0}})

      html =
        rendered_to_string(~H"""
        <.data_table id="t" rows={@rows} state={@state} on_change="table" selectable>
          <:col :let={row} field={:name}>{row.name}</:col>
        </.data_table>
        """)

      assert [_] = attrs(html, "th input[data-pc-dt-select-page]", "disabled")
      assert html =~ ~s(colspan="2")
    end
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
