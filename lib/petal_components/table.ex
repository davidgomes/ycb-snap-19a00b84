defmodule PetalComponents.Table do
  use Phoenix.Component

  import PetalComponents.Avatar

  @doc ~S"""
  Renders a table with generic styling.

  ## Examples

      <.table id="users" rows={@users}>
        <:col :let={user} label="id"><%= user.id %></:col>
        <:col :let={user} label="username"><%= user.username %></:col>
        <:empty_state>No data here yet</:empty_state>
      </.table>
  """
  attr :id, :string
  attr :class, :any, default: nil, doc: "CSS class"
  attr :variant, :string, default: "basic", values: ["ghost", "basic"]
  attr :rows, :list, default: [], doc: "the list of rows to render"
  attr :row_id, :any, default: nil, doc: "the function for generating the row id"
  attr :row_click, :any, default: nil, doc: "the function for handling phx-click on each row"

  attr :row_item, :any,
    default: &Function.identity/1,
    doc: "the function for mapping each row before calling the :col slot"

  attr :density, :string,
    default: "comfortable",
    values: ["comfortable", "compact"],
    doc: "row height. compact halves the vertical padding for data-heavy screens"

  attr :sticky_header, :boolean,
    default: false,
    doc:
      "keep the header row pinned while the table scrolls (the table needs a scrollable ancestor)"

  attr :striped, :boolean, default: false, doc: "wash alternate rows for easier scanning"

  attr :sort_by, :any, default: nil, doc: "the currently sorted column's sort_key"

  attr :sort_dir, :string,
    default: "asc",
    values: ["asc", "desc"],
    doc: "the current sort direction"

  attr :on_sort, :any,
    default: "sort",
    doc: """
    event name (or JS command) fired when a sortable header is clicked;
    receives phx-value-sort of the column's sort_key. May also be a
    1-arity function of the sort_key returning the event/JS per column -
    how the data table patches per-column sort URLs in link mode.
    """

  attr :selectable, :boolean,
    default: false,
    doc: "render a leading checkbox column; the header checkbox is tri-state across `rows`"

  attr :selected, :list, default: [], doc: "ids (per row_id) of the currently selected rows"

  attr :on_select, :any,
    default: nil,
    doc:
      "event name (or JS command) fired when a row's checkbox toggles; receives phx-value-id (row_id(row)) and phx-value-checked (the next state)"

  attr :on_select_all, :any,
    default: nil,
    doc:
      "event name (or JS command) fired when the header checkbox toggles; receives phx-value-checked (the next state)"

  attr :select_target, :any, default: nil, doc: "phx-target for on_select / on_select_all"

  slot :col do
    attr :label, :string
    attr :class, :any
    attr :row_class, :any
    attr :sortable, :boolean, doc: "render the header as a sort button"
    attr :sort_key, :string, doc: "the key sent with on_sort (defaults to the downcased label)"
  end

  slot :empty_state,
    doc: "A message to show when the table is empty, to be used together with :col" do
    attr :row_class, :any
  end

  slot :footer,
    doc:
      "a totals/summary row pinned under the body - supply <.td> cells (colspan works), e.g. <.td colspan={3}>Total</.td><.td>$2,500</.td>"

  attr :rest, :global, include: ~w(colspan rowspan)

  def table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    if assigns.selectable and is_nil(assigns.row_id) do
      raise ArgumentError, "table needs row_id when selectable is set"
    end

    assigns = assign_new(assigns, :id, fn -> "table_#{Ecto.UUID.generate()}" end)

    {all_selected?, indeterminate?} = selection_state(assigns)

    assigns =
      assigns
      |> assign(:all_selected?, all_selected?)
      |> assign(:indeterminate?, indeterminate?)
      |> assign(:colspan, length(assigns.col) + if(assigns.selectable, do: 1, else: 0))

    ~H"""
    <table
      class={[
        "pc-table--#{@variant}",
        @density == "compact" && "pc-table--compact",
        @striped && "pc-table--striped",
        @class
      ]}
      {@rest}
    >
      <%= if @col != [] do %>
        <thead>
          <.tr>
            <.th :if={@selectable} class="pc-table__th--select">
              <input
                type="checkbox"
                class="pc-checkbox"
                checked={@all_selected?}
                data-indeterminate={@indeterminate? && "true"}
                data-pc-dt-select-all
                phx-click={@on_select_all}
                phx-value-checked={to_string(!@all_selected?)}
                phx-target={@select_target}
                aria-label="Select all rows"
              />
            </.th>
            <.th
              :for={col <- @col}
              class={[col[:class], @sticky_header && "pc-table__th--sticky"]}
              aria-sort={col[:sortable] && aria_sort(sort_state(col, @sort_by, @sort_dir))}
            >
              <%= if col[:sortable] do %>
                <button
                  type="button"
                  class="pc-table__sort"
                  phx-click={resolve_on_sort(@on_sort, sort_key(col))}
                  phx-value-sort={sort_key(col)}
                >
                  {col[:label]}
                  <.sort_icon state={sort_state(col, @sort_by, @sort_dir)} />
                </button>
              <% else %>
                {col[:label]}
              <% end %>
            </.th>
          </.tr>
        </thead>
        <tbody id={@id} phx-update={match?(%Phoenix.LiveView.LiveStream{}, @rows) && "stream"}>
          <.tr
            :if={@empty_state != []}
            id={@id <> "-empty"}
            class="pc-table__tr--empty hidden only:table-row"
          >
            <.td
              :for={empty_state <- @empty_state}
              colspan={@colspan}
              class={empty_state[:row_class]}
            >
              {render_slot(empty_state)}
            </.td>
          </.tr>
          <.tr
            :for={row <- @rows}
            id={@row_id && @row_id.(row)}
            class={["group", @row_click && "pc-table__tr--row-click"]}
          >
            <.td :if={@selectable} class="pc-table__td--select">
              <input
                type="checkbox"
                class="pc-checkbox"
                checked={@row_id.(row) in @selected}
                phx-click={@on_select}
                phx-value-id={@row_id.(row)}
                phx-value-checked={to_string(@row_id.(row) not in @selected)}
                phx-target={@select_target}
                aria-label="Select row"
              />
            </.td>
            <.td
              :for={{col, i} <- Enum.with_index(@col)}
              phx-click={@row_click && @row_click.(row)}
              class={[
                @row_click && "pc-table__td--row-click",
                i == 0 && "pc-table__td--first-col",
                col[:row_class] && col[:row_class]
              ]}
            >
              {render_slot(col, @row_item.(row))}
            </.td>
          </.tr>
        </tbody>
        <tfoot :if={@footer != []} class="pc-table__tfoot">
          <.tr>
            {render_slot(@footer)}
          </.tr>
        </tfoot>
      <% else %>
        {render_slot(@inner_block)}
      <% end %>
    </table>
    """
  end

  defp resolve_on_sort(on_sort, key) when is_function(on_sort, 1), do: on_sort.(key)
  defp resolve_on_sort(on_sort, _key), do: on_sort

  # the header checkbox's tri-state: checked when every current row is
  # selected, indeterminate when only some are - native <input> has no
  # indeterminate HTML attribute, so data-indeterminate is a hand-off to
  # the PetalDataTable hook, which sets the DOM property on mount/update
  defp selection_state(%{selectable: false}), do: {false, false}

  defp selection_state(%{selectable: true, rows: rows, row_id: row_id, selected: selected}) do
    ids = Enum.map(rows, row_id)
    selected_count = Enum.count(ids, &(&1 in selected))

    cond do
      ids == [] or selected_count == 0 -> {false, false}
      selected_count == length(ids) -> {true, false}
      true -> {false, true}
    end
  end

  defp sort_key(col), do: col[:sort_key] || String.downcase(col[:label] || "")

  defp sort_state(col, sort_by, sort_dir) do
    if sort_by && to_string(sort_by) == sort_key(col), do: sort_dir, else: "none"
  end

  defp aria_sort("asc"), do: "ascending"
  defp aria_sort("desc"), do: "descending"
  defp aria_sort(_state), do: nil

  attr :state, :string, required: true

  defp sort_icon(assigns) do
    ~H"""
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      stroke-linecap="round"
      stroke-linejoin="round"
      class={["pc-table__sort-icon", @state != "none" && "pc-table__sort-icon--active"]}
      aria-hidden="true"
    >
      <path :if={@state == "asc"} d="m5 15 7-7 7 7" />
      <path :if={@state == "desc"} d="m19 9-7 7-7-7" />
      <g :if={@state == "none"}><path d="m7 9 5-5 5 5" /><path d="m7 15 5 5 5-5" /></g>
    </svg>
    """
  end

  attr(:class, :any, default: nil, doc: "CSS class")
  attr(:rest, :global, include: ~w(colspan rowspan))
  slot(:inner_block, required: false)

  def th(assigns) do
    ~H"""
    <th class={["pc-table__th", @class]} {@rest}>
      {render_slot(@inner_block)}
    </th>
    """
  end

  attr(:class, :any, default: nil, doc: "CSS class")
  attr(:rest, :global)
  slot(:inner_block, required: false)

  def tr(assigns) do
    ~H"""
    <tr class={["pc-table__tr", @class]} {@rest}>
      {render_slot(@inner_block)}
    </tr>
    """
  end

  attr(:class, :any, default: nil, doc: "CSS class")
  attr(:rest, :global, include: ~w(colspan headers rowspan))
  slot(:inner_block, required: false)

  def td(assigns) do
    ~H"""
    <td class={["pc-table__td", @class]} {@rest}>
      {render_slot(@inner_block)}
    </td>
    """
  end

  attr(:class, :any, default: nil, doc: "CSS class")
  attr(:label, :string, default: nil, doc: "Adds a label your user, e.g name")
  attr(:sub_label, :string, default: nil, doc: "Adds a sub-label your to your user, e.g title")
  attr(:rest, :global)

  attr(:avatar_assigns, :map,
    default: nil,
    doc: "if using an avatar, this map will be passed to the avatar component as props"
  )

  def user_inner_td(assigns) do
    ~H"""
    <div class={@class} {@rest}>
      <div class="pc-table__user-inner-td">
        <%= if @avatar_assigns do %>
          <.avatar {@avatar_assigns} />
        <% end %>

        <div class="pc-table__user-inner-td__inner">
          <div class="pc-table__user-inner-td__label">
            {@label}
          </div>
          <div class="pc-table__user-inner-td__sub-label">
            {@sub_label}
          </div>
        </div>
      </div>
    </div>
    """
  end
end
