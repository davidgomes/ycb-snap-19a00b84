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
    @keyed [%{id: 1, name: "Amy"}, %{id: 2, name: "Bea"}]

    defp header_checkbox(html) do
      [box] = Regex.run(~r/<input[^>]*data-pc-dt-select-all[^>]*>/, html)
      box
    end

    defp row_checkboxes(html) do
      ~r/<input[^>]*aria-label="Select row"[^>]*>/ |> Regex.scan(html) |> List.flatten()
    end

    defp push_value(tag) do
      [json] = Regex.run(~r/phx-click="([^"]*)"/, tag, capture: :all_but_first)
      [["push", %{"value" => value}]] = json |> String.replace("&quot;", "\"") |> Jason.decode!()
      value
    end

    test "off by default: no checkbox column, no selection bar" do
      assigns = base(%{rows: @keyed})

      html =
        rendered_to_string(~H"""
        <.data_table id="t" rows={@rows} state={@state} path={@path}>
          <:col :let={row} field={:name}>{row.name}</:col>
        </.data_table>
        """)

      refute html =~ "pc-data-table__select"
      refute html =~ "pc-data-table__selection-count"
    end

    test "the header is tri-state over the visible page" do
      assigns = base(%{rows: @keyed})

      render = fn selected ->
        assigns = Map.put(assigns, :selected, selected)

        rendered_to_string(~H"""
        <.data_table
          id="t"
          rows={@rows}
          state={@state}
          path={@path}
          on_select="select"
          selected={@selected}
        >
          <:col :let={row} field={:name}>{row.name}</:col>
        </.data_table>
        """)
        |> header_checkbox()
      end

      none = render.([])
      refute none =~ " checked"
      refute none =~ "data-indeterminate"
      assert push_value(none) == %{"op" => "select", "ids" => [1, 2], "checked" => true}

      # an off-page key doesn't count toward the page's state
      some = render.([2, 99])
      refute some =~ " checked"
      assert some =~ "data-indeterminate"
      assert push_value(some) == %{"op" => "select", "ids" => [1, 2], "checked" => true}

      all = render.([1, 2])
      assert all =~ " checked"
      refute all =~ "data-indeterminate"
      assert push_value(all) == %{"op" => "select", "ids" => [1, 2], "checked" => false}
      assert all =~ ~s(aria-label="Select all rows on this page")
    end

    test "row checkboxes reflect the selection and push their own key" do
      assigns = base(%{rows: @keyed})

      html =
        rendered_to_string(~H"""
        <.data_table
          id="t"
          rows={@rows}
          state={@state}
          on_change="table"
          on_select="select"
          selected={[2]}
        >
          <:col :let={row} field={:name}>{row.name}</:col>
        </.data_table>
        """)

      assert [amy, bea] = row_checkboxes(html)
      refute amy =~ " checked"
      assert bea =~ " checked"
      assert push_value(amy) == %{"op" => "select", "ids" => [1], "checked" => true}
      assert push_value(bea) == %{"op" => "select", "ids" => [2], "checked" => false}
      # the select-all tri-state needs the hook, even in event mode
      assert html =~ ~s(phx-hook="PetalDataTable")
    end

    test "row_key picks the selection key" do
      assigns = base(%{rows: [%{sku: "a-1", name: "Amy"}]})

      html =
        rendered_to_string(~H"""
        <.data_table id="t" rows={@rows} state={@state} path={@path} on_select="select" row_key={& &1.sku}>
          <:col :let={row} field={:name}>{row.name}</:col>
        </.data_table>
        """)

      assert [box] = row_checkboxes(html)
      assert push_value(box)["ids"] == ["a-1"]
    end

    test "while rows are selected the toolbar morphs into the selection bar" do
      assigns = base(%{rows: @keyed})

      idle =
        rendered_to_string(~H"""
        <.data_table id="t" rows={@rows} state={@state} path={@path} searchable on_select="select">
          <:col :let={row} field={:name}>{row.name}</:col>
          <:bulk_action :let={ids}><button type="button">Refund {length(ids)}</button></:bulk_action>
        </.data_table>
        """)

      refute idle =~ "pc-data-table__toolbar--selecting"
      refute idle =~ "Clear selection"
      refute idle =~ "Refund"
      assert idle =~ ~s(role="status")
      assert idle =~ "pc-data-table__selection-count--idle"
      refute idle =~ ~r/pc-data-table__toolbar-main"[^>]*hidden/

      selecting =
        rendered_to_string(~H"""
        <.data_table
          id="t"
          rows={@rows}
          state={@state}
          path={@path}
          searchable
          on_select="select"
          selected={[1, 2, 7]}
          selected_label="ausgewählt"
        >
          <:col :let={row} field={:name}>{row.name}</:col>
          <:bulk_action :let={ids}><button type="button">Refund {length(ids)}</button></:bulk_action>
        </.data_table>
        """)

      assert selecting =~ "pc-data-table__toolbar--selecting"
      # the count spans pages; the bulk slot receives every selected key
      assert selecting =~ "3 ausgewählt"
      assert selecting =~ "Refund 3"
      assert selecting =~ ~s(&quot;op&quot;:&quot;clear_selection&quot;)
      # the regular toolbar is hidden, not removed: the search input stays
      # in the DOM for the hook's link-mode URLs
      assert selecting =~ ~r/pc-data-table__toolbar-main"[^>]*hidden/
      assert selecting =~ "data-pc-dt-search"
    end

    test "loading and empty pages disable the header and drop row checkboxes" do
      assigns = base(%{rows: @keyed, state: %State{total: 74, page_size: 3}})

      loading =
        rendered_to_string(~H"""
        <.data_table id="t" rows={@rows} state={@state} path={@path} on_select="select" loading>
          <:col :let={row} field={:name}>{row.name}</:col>
        </.data_table>
        """)

      assert row_checkboxes(loading) == []
      assert header_checkbox(loading) =~ " disabled"

      assigns = base(%{rows: [], state: %State{total: 0}})

      empty =
        rendered_to_string(~H"""
        <.data_table id="t" rows={@rows} state={@state} path={@path} on_select="select">
          <:col :let={row} field={:name}>{row.name}</:col>
        </.data_table>
        """)

      assert header_checkbox(empty) =~ " disabled"
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
