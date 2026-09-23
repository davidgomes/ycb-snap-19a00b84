defmodule PetalComponents.DataTable.Selection do
  @moduledoc """
  The data table's row-selection grammar, as a pure reducer over a
  `MapSet` of row ids.

  Selection is deliberately NOT part of `PetalComponents.DataTable.State`:
  it is not query state (it never belongs in a URL), and keeping it
  outside means rebuilding the State in `handle_params` never drops it.
  The consumer owns one assign and folds every selection op into it:

      def handle_event("table", params, socket) do
        selected = Selection.handle_op(socket.assigns.selected, params)
        state = State.handle_op(socket.assigns.table, params, fields: [:name])
        ...
      end

  Both reducers ignore ops that aren't theirs, so one event can carry
  the whole grammar.

  Ids travel through the DOM, so they are normalized to strings: the
  returned set always holds strings, whatever the rows' id type.

  Ops:

    * `%{"op" => "select", "id" => id}` - toggle one row
    * `%{"op" => "select_page", "ids" => ids, "checked" => bool}` - the
      tri-state header: add (checked) or remove (unchecked) the page's ids,
      leaving selections on other pages alone
    * `%{"op" => "clear_selection"}` - drop everything
  """

  @doc "Normalizes any enumerable of ids (or nil) to a `MapSet` of strings."
  def new(nil), do: MapSet.new()
  def new(ids), do: MapSet.new(ids, &to_string/1)

  @doc "Applies one selection op; foreign ops return the selection unchanged."
  def handle_op(selected, params) when is_map(params) do
    selected = new(selected)

    case params do
      %{"op" => "select", "id" => id} ->
        id = to_string(id)

        if MapSet.member?(selected, id),
          do: MapSet.delete(selected, id),
          else: MapSet.put(selected, id)

      %{"op" => "select_page", "ids" => ids} when is_list(ids) ->
        ids = new(ids)

        if truthy?(params["checked"]),
          do: MapSet.union(selected, ids),
          else: MapSet.difference(selected, ids)

      %{"op" => "clear_selection"} ->
        MapSet.new()

      _other ->
        selected
    end
  end

  @doc """
  The header checkbox's state for a page of ids: `:all`, `:some`
  (the indeterminate middle) or `:none`. An empty page reads `:none`.
  """
  def page_state(selected, page_ids) do
    selected = new(selected)
    on_page = Enum.count(page_ids, &MapSet.member?(selected, to_string(&1)))

    cond do
      on_page == 0 -> :none
      on_page == length(page_ids) -> :all
      true -> :some
    end
  end

  # JS.push values arrive as JSON booleans; hand-built payloads may be strings
  defp truthy?(value), do: value in [true, "true"]
end
